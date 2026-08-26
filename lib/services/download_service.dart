import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DownloadItem {
  final String id;
  final String lectureId;
  final String lectureTitle;
  final String title;
  final String fileType;
  final String localPath;
  final int sizeBytes;
  final DateTime downloadedAt;

  const DownloadItem({
    required this.id,
    required this.lectureId,
    required this.lectureTitle,
    required this.title,
    required this.fileType,
    required this.localPath,
    required this.sizeBytes,
    required this.downloadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lectureId': lectureId,
      'lectureTitle': lectureTitle,
      'title': title,
      'fileType': fileType,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  factory DownloadItem.fromMap(
    Map<String, dynamic> map,
  ) {
    return DownloadItem(
      id: map['id']?.toString() ?? '',
      lectureId:
          map['lectureId']?.toString() ?? '',
      lectureTitle:
          map['lectureTitle']?.toString() ??
              'Unknown Lecture',
      title:
          map['title']?.toString() ?? '',
      fileType:
          map['fileType']?.toString() ?? '',
      localPath:
          map['localPath']?.toString() ?? '',
      sizeBytes:
          (map['sizeBytes'] as num?)
                  ?.toInt() ??
              0,
      downloadedAt:
          DateTime.tryParse(
                map['downloadedAt']
                        ?.toString() ??
                    '',
              ) ??
              DateTime.now(),
    );
  }
}

class DownloadProgress {
  final String id;
  final double progress;
  final int receivedBytes;
  final int totalBytes;

  const DownloadProgress({
    required this.id,
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
  });
}

class DownloadsService {
  DownloadsService._();

  static final DownloadsService instance =
      DownloadsService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  final Dio _dio = Dio();

  final Connectivity _connectivity =
      Connectivity();

  static const String _preferencesKey =
      'local_downloads_v2';

  static const Duration
      _temporaryFileLifetime =
      Duration(hours: 24);

  // ==========================================================================
  // LIVE PROGRESS
  // ==========================================================================

  final ValueNotifier<Map<String, double>>
      progressNotifier =
      ValueNotifier<Map<String, double>>({});

  final ValueNotifier<List<DownloadItem>>
      activeDownloadItemsNotifier =
      ValueNotifier<List<DownloadItem>>([]);

  final ValueNotifier<Set<String>>
      activeDownloadsNotifier =
      ValueNotifier<Set<String>>({});

  void _setProgress(
    String id,
    double value,
  ) {
    final updated =
        Map<String, double>.from(
      progressNotifier.value,
    );

    updated[id] =
        value.clamp(0.0, 1.0);

    progressNotifier.value =
        updated;
  }

  void _addActiveDownload(
    DownloadItem item,
  ) {
    final current =
        List<DownloadItem>.from(
      activeDownloadItemsNotifier.value,
    );

    current.removeWhere(
      (existing) =>
          existing.id == item.id,
    );

    current.add(item);

    activeDownloadItemsNotifier.value =
        current;
  }

  void _removeActiveDownload(
    String id,
  ) {
    final current =
        List<DownloadItem>.from(
      activeDownloadItemsNotifier.value,
    );

    current.removeWhere(
      (item) => item.id == id,
    );

    activeDownloadItemsNotifier.value =
        current;
  }

  void _startProgress(
    String id,
  ) {
    final updated =
        Set<String>.from(
      activeDownloadsNotifier.value,
    );

    updated.add(id);

    activeDownloadsNotifier.value =
        updated;

    _setProgress(
      id,
      0.0,
    );
  }

  void _finishProgress(
    String id,
  ) {
    final progress =
        Map<String, double>.from(
      progressNotifier.value,
    );

    progress.remove(id);

    progressNotifier.value =
        progress;

    final active =
        Set<String>.from(
      activeDownloadsNotifier.value,
    );

    active.remove(id);

    activeDownloadsNotifier.value =
        active;
  }

  // ==========================================================================
  // CONNECTION
  // ==========================================================================

  Future<List<ConnectivityResult>>
      getConnectivityResults() async {
    try {
      return await _connectivity
          .checkConnectivity();
    } catch (e) {
      debugPrint(
        'Connectivity check error: $e',
      );

      return const [];
    }
  }

  Future<bool>
      isWifiConnection() async {
    final results =
        await getConnectivityResults();

    return results.contains(
      ConnectivityResult.wifi,
    );
  }

  Future<bool>
      isMobileDataConnection() async {
    final results =
        await getConnectivityResults();

    return results.contains(
      ConnectivityResult.mobile,
    );
  }

  Future<bool>
      isOfflineConnection() async {
    final results =
        await getConnectivityResults();

    return results.isEmpty ||
        results.contains(
          ConnectivityResult.none,
        );
  }

  // ==========================================================================
  // TEMPORARY FILE CLEANUP
  // ==========================================================================

  Future<void>
      _cleanupTemporaryLectureFiles() async {
    try {
      final directory =
          await getTemporaryDirectory();

      if (!await directory.exists()) {
        return;
      }

      final now =
          DateTime.now();

      await for (
        final entity
        in directory.list(
          recursive: false,
          followLinks: false,
        )
      ) {
        if (entity is! File) {
          continue;
        }

        final name =
            entity.path
                .split(
                  Platform.pathSeparator,
                )
                .last;

        if (!name.startsWith(
          'lecture_',
        )) {
          continue;
        }

        try {
          final modified =
              await entity.lastModified();

          if (now
                  .difference(modified) >
              _temporaryFileLifetime) {
            await entity.delete();
          }
        } catch (e) {
          debugPrint(
            'Temporary lecture cleanup item error: $e',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'Temporary lecture cleanup error: $e',
      );
    }
  }

  // ==========================================================================
  // OPEN LECTURE FILE
  // ==========================================================================

  Future<void> openLectureFile({
    required String id,
    required String title,
    required String fileType,
    required String fileUrl,
  }) async {
    await _cleanupTemporaryLectureFiles();

    // ------------------------------------------------------------------------
    // LOCAL
    // ------------------------------------------------------------------------

    final localItem =
        await findById(id);

    if (localItem != null) {
      final localFile =
          File(localItem.localPath);

      if (await localFile.exists()) {
        await open(localItem);
        return;
      }

      await delete(id);
    }

    // ------------------------------------------------------------------------
    // SIGNED URL
    // ------------------------------------------------------------------------

    final signedUrl =
        await _createSignedUrl(
      fileUrl: fileUrl,
      fileType: fileType,
    );

    // ------------------------------------------------------------------------
    // TEMP DIRECTORY
    // ------------------------------------------------------------------------

    final tempDirectory =
        await getTemporaryDirectory();

    if (!await tempDirectory.exists()) {
      await tempDirectory.create(
        recursive: true,
      );
    }

    final safeName =
        _buildTemporaryFileName(
      title,
      fileType,
    );

    final initialPath =
        '${tempDirectory.path}/$safeName';

    final uniquePath =
        await _createUniquePath(
      initialPath,
    );

    final tempFile =
        File(uniquePath);

    try {
      await _dio.download(
        signedUrl,
        uniquePath,
      );

      if (!await tempFile.exists()) {
        throw Exception(
          'Unable to prepare the file.',
        );
      }

      final result =
          await OpenFilex.open(
        tempFile.path,
      );

      if (result.type !=
          ResultType.done) {
        throw Exception(
          result.message.isNotEmpty
              ? result.message
              : 'No compatible app was found.',
        );
      }
    } catch (e) {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      rethrow;
    }
  }

  // ==========================================================================
  // DOWNLOAD DIRECTORY
  // ==========================================================================

  Future<Directory>
      _getDownloadsDirectory() async {
    final baseDirectory =
        await getApplicationDocumentsDirectory();

    final directory =
        Directory(
      '${baseDirectory.path}/downloads',
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  // ==========================================================================
  // LOAD DOWNLOADS
  // ==========================================================================

  Future<List<DownloadItem>>
      getDownloads() async {
    final preferences =
        await SharedPreferences
            .getInstance();

    final raw =
        preferences
                .getStringList(
              _preferencesKey,
            ) ??
            [];

    final items =
        <DownloadItem>[];

    for (final value in raw) {
      try {
        final decoded =
            jsonDecode(value);

        if (decoded is! Map) {
          continue;
        }

        final item =
            DownloadItem.fromMap(
          Map<String, dynamic>.from(
            decoded,
          ),
        );

        final file =
            File(item.localPath);

        if (await file.exists()) {
          items.add(item);
        }
      } catch (e) {
        debugPrint(
          'Download metadata error: $e',
        );
      }
    }

    items.sort(
      (a, b) =>
          b.downloadedAt
              .compareTo(
        a.downloadedAt,
      ),
    );

    await _saveDownloads(
      items,
    );

    return items;
  }

  // ==========================================================================
  // SAVE
  // ==========================================================================

  Future<void> _saveDownloads(
    List<DownloadItem> items,
  ) async {
    final preferences =
        await SharedPreferences
            .getInstance();

    await preferences
        .setStringList(
      _preferencesKey,
      items
          .map(
            (item) =>
                jsonEncode(
              item.toMap(),
            ),
          )
          .toList(),
    );
  }

  // ==========================================================================
  // FIND
  // ==========================================================================

  Future<DownloadItem?> findById(
    String id,
  ) async {
    final downloads =
        await getDownloads();

    for (final item
        in downloads) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }

  // ==========================================================================
  // SIGNED URL
  // ==========================================================================

  Future<String> _createSignedUrl({
    required String fileUrl,
    required String fileType,
  }) async {
    final bucket =
        _bucketForType(
      fileType,
    );

    final storagePath =
        _extractStoragePath(
      fileUrl,
      bucket,
    );

    if (storagePath.isEmpty) {
      throw Exception(
        'Invalid storage path.',
      );
    }

    return _supabase.storage
        .from(bucket)
        .createSignedUrl(
      storagePath,
      3600,
    );
  }

  Future<String>
      createSignedUrlForLectureFile({
    required String fileUrl,
    required String fileType,
  }) async {
    return _createSignedUrl(
      fileUrl: fileUrl,
      fileType: fileType,
    );
  }

  // ==========================================================================
  // DOWNLOAD
  //
  // IMPORTANT:
  // This method intentionally does NOT block mobile-data downloads.
  // The UI performs the warning/confirmation before calling it.
  // ==========================================================================

  Future<DownloadItem> download({
    required String id,
    required String lectureId,
    required String lectureTitle,
    required String title,
    required String fileType,
    required String fileUrl,
    void Function(
      DownloadProgress progress,
    )?
    onProgress,
    CancelToken? cancelToken,
  }) async {
    // ------------------------------------------------------------------------
    // EXISTING
    // ------------------------------------------------------------------------

    final existing =
        await findById(id);

    if (existing != null) {
      final file =
          File(existing.localPath);

      if (await file.exists()) {
        return existing;
      }

      await delete(id);
    }

    // ------------------------------------------------------------------------
    // SIGNED URL
    // ------------------------------------------------------------------------

    final signedUrl =
        await _createSignedUrl(
      fileUrl: fileUrl,
      fileType: fileType,
    );

    final directory =
        await _getDownloadsDirectory();

    final safeName =
        _buildSafeFileName(
      title,
      fileType,
    );

    final finalPath =
        '${directory.path}/$safeName';

    final uniquePath =
        await _createUniquePath(
      finalPath,
    );

    final tempPath =
        '$uniquePath.part';

    final activeItem =
        DownloadItem(
      id: id,
      lectureId: lectureId,
      lectureTitle:
          lectureTitle,
      title:
          title,
      fileType:
          fileType,
      localPath:
          tempPath,
      sizeBytes:
          0,
      downloadedAt:
          DateTime.now(),
    );

    _addActiveDownload(
      activeItem,
    );

    _startProgress(id);

    try {
      await _dio.download(
        signedUrl,
        tempPath,
        cancelToken:
            cancelToken,
        deleteOnError:
            true,
        onReceiveProgress:
            (
          received,
          total,
        ) {
          final progress =
              total > 0
                  ? received / total
                  : 0.0;

          _setProgress(
            id,
            progress,
          );

          onProgress?.call(
            DownloadProgress(
              id:
                  id,
              progress:
                  progress.clamp(
                0.0,
                1.0,
              ),
              receivedBytes:
                  received,
              totalBytes:
                  total,
            ),
          );
        },
      );

      final temporaryFile =
          File(tempPath);

      if (!await temporaryFile.exists()) {
        throw Exception(
          'Downloaded file was not created.',
        );
      }

      final file =
          await temporaryFile.rename(
        uniquePath,
      );

      final size =
          await file.length();

      final item =
          DownloadItem(
        id:
            id,
        lectureId:
            lectureId,
        lectureTitle:
            lectureTitle,
        title:
            title,
        fileType:
            fileType,
        localPath:
            file.path,
        sizeBytes:
            size,
        downloadedAt:
            DateTime.now(),
      );

      final current =
          await getDownloads();

      final updated =
          current
              .where(
                (existing) =>
                    existing.id !=
                    id,
              )
              .toList()
            ..add(item);

      await _saveDownloads(
        updated,
      );

      _setProgress(
        id,
        1.0,
      );

      onProgress?.call(
        DownloadProgress(
          id:
              id,
          progress:
              1.0,
          receivedBytes:
              size,
          totalBytes:
              size,
        ),
      );

      return item;
    } catch (e) {
      final tempFile =
          File(tempPath);

      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      rethrow;
    } finally {
      _removeActiveDownload(
        id,
      );

      _finishProgress(
        id,
      );
    }
  }

  // ==========================================================================
  // OPEN
  // ==========================================================================

  Future<void> open(
    DownloadItem item,
  ) async {
    final file =
        File(item.localPath);

    if (!await file.exists()) {
      await delete(item.id);

      throw Exception(
        'This downloaded file no longer exists.',
      );
    }

    final result =
        await OpenFilex.open(
      file.path,
    );

    if (result.type !=
        ResultType.done) {
      throw Exception(
        result.message.isNotEmpty
            ? result.message
            : 'Unable to open file.',
      );
    }
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  Future<void> delete(
    String id,
  ) async {
    final preferences =
        await SharedPreferences
            .getInstance();

    final raw =
        preferences
                .getStringList(
              _preferencesKey,
            ) ??
            [];

    final remaining =
        <String>[];

    for (final value in raw) {
      try {
        final decoded =
            jsonDecode(value);

        if (decoded is! Map) {
          continue;
        }

        final item =
            DownloadItem.fromMap(
          Map<String, dynamic>.from(
            decoded,
          ),
        );

        if (item.id == id) {
          final file =
              File(
            item.localPath,
          );

          if (await file.exists()) {
            await file.delete();
          }
        } else {
          remaining.add(value);
        }
      } catch (_) {}
    }

    await preferences
        .setStringList(
      _preferencesKey,
      remaining,
    );
  }

  // ==========================================================================
  // DELETE ALL
  // ==========================================================================

  Future<void> deleteAll() async {
    final downloads =
        await getDownloads();

    for (final item
        in downloads) {
      final file =
          File(item.localPath);

      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    final preferences =
        await SharedPreferences
            .getInstance();

    await preferences.remove(
      _preferencesKey,
    );
  }

  // ==========================================================================
  // BUCKET
  // ==========================================================================

  String _bucketForType(
    String type,
  ) {
    switch (
        type.toLowerCase().trim()) {
      case 'pdf':
        return 'Lecture pdfs';

      case 'audio':
        return 'Lecture audios';

      case 'video':
        return 'lecture videos';

      default:
        throw Exception(
          'Unsupported lecture file type: $type',
        );
    }
  }

  // ==========================================================================
  // STORAGE PATH
  // ==========================================================================

  String _extractStoragePath(
    String value,
    String bucket,
  ) {
    final trimmed =
        value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    if (!trimmed.startsWith(
          'http://',
        ) &&
        !trimmed.startsWith(
          'https://',
        )) {
      return trimmed;
    }

    final uri =
        Uri.tryParse(
      trimmed,
    );

    if (uri == null) {
      return trimmed;
    }

    final segments =
        uri.pathSegments;

    final bucketIndex =
        segments.indexWhere(
      (
        segment,
      ) =>
          Uri.decodeComponent(
            segment,
          ) ==
          bucket,
    );

    if (bucketIndex == -1) {
      throw Exception(
        'Bucket "$bucket" was not found in file URL.',
      );
    }

    if (bucketIndex +
            1 >=
        segments.length) {
      return '';
    }

    return segments
        .sublist(
          bucketIndex + 1,
        )
        .map(
          Uri.decodeComponent,
        )
        .join('/');
  }

  // ==========================================================================
  // SAFE FILE NAME
  // ==========================================================================

  String _buildSafeFileName(
    String title,
    String fileType,
  ) {
    final cleaned =
        title
            .trim()
            .replaceAll(
              RegExp(
                r'[\\/:*?"<>|]',
              ),
              '_',
            )
            .replaceAll(
              RegExp(
                r'\s+',
              ),
              ' ',
            );

    final extension =
        _extensionForType(
      fileType,
    );

    return
        '${cleaned.isEmpty ? 'lecture' : cleaned}.$extension';
  }

  String _buildTemporaryFileName(
    String title,
    String fileType,
  ) {
    final cleaned =
        title
            .trim()
            .replaceAll(
              RegExp(
                r'[\\/:*?"<>|]',
              ),
              '_',
            )
            .replaceAll(
              RegExp(
                r'\s+',
              ),
              '_',
            );

    final extension =
        _extensionForType(
      fileType,
    );

    final timestamp =
        DateTime.now()
            .millisecondsSinceEpoch;

    return
        'lecture_${cleaned.isEmpty ? 'file' : cleaned}_$timestamp.$extension';
  }

  String _extensionForType(
    String fileType,
  ) {
    switch (
        fileType.toLowerCase().trim()) {
      case 'pdf':
        return 'pdf';

      case 'audio':
        return 'mp3';

      case 'video':
        return 'mp4';

      default:
        return 'file';
    }
  }

  // ==========================================================================
  // UNIQUE PATH
  // ==========================================================================

  Future<String> _createUniquePath(
    String originalPath,
  ) async {
    final file =
        File(originalPath);

    if (!await file.exists()) {
      return originalPath;
    }

    final directory =
        file.parent;

    final originalName =
        file.uri
            .pathSegments
            .last;

    final dotIndex =
        originalName.lastIndexOf(
      '.',
    );

    final baseName =
        dotIndex > 0
            ? originalName.substring(
                0,
                dotIndex,
              )
            : originalName;

    final extension =
        dotIndex > 0
            ? originalName.substring(
                dotIndex,
              )
            : '';

    var counter = 2;

    while (true) {
      final candidate =
          File(
        '${directory.path}/'
        '$baseName ($counter)'
        '$extension',
      );

      if (!await candidate.exists()) {
        return candidate.path;
      }

      counter++;
    }
  }

  // ==========================================================================
  // FORMAT
  // ==========================================================================

  static String formatBytes(
    int bytes,
  ) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes <
        1024 * 1024) {
      return
          '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes <
        1024 *
            1024 *
            1024) {
      return
          '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return
        '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  void dispose() {
    progressNotifier.dispose();
    activeDownloadsNotifier.dispose();
    activeDownloadItemsNotifier.dispose();
  }
}
