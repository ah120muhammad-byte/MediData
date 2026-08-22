import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/downloaded_file.dart';

class DownloadService {
  DownloadService._();

  static final DownloadService instance = DownloadService._();

  final Dio _dio = Dio();

  static const String _metadataFileName = 'downloaded_files.json';

  // ===========================================================================
  // ACTIVE DOWNLOADS
  // ===========================================================================

  final Map<String, double> _progress = {};

  final Map<String, StreamController<double>> _controllers = {};

  // ===========================================================================
  // PROGRESS STREAM
  // ===========================================================================

  Stream<double> progressStream(String id) {
    final controller = _controllers.putIfAbsent(
      id,
      () => StreamController<double>.broadcast(),
    );

    return controller.stream;
  }

  double progressOf(String id) {
    return _progress[id] ?? 0.0;
  }

  // ===========================================================================
  // DOWNLOAD
  // ===========================================================================

  Future<DownloadedFile> download({
    required String id,
    required String lectureId,
    required String title,
    required String fileType,
    required String url,
  }) async {
    final directory = await _downloadDirectory();

    final extension = _extensionForType(
      fileType,
      url,
    );

    final safeTitle = _sanitizeFileName(title);

    final fileName = extension.isEmpty
        ? safeTitle
        : '$safeTitle.$extension';

    final filePath = '${directory.path}/$fileName';

    _progress[id] = 0;

    _emitProgress(id, 0);

    try {
      await _dio.download(
        url,
        filePath,
        deleteOnError: true,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) {
            return status != null &&
                status >= 200 &&
                status < 400;
          },
        ),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            return;
          }

          final value = received / total;

          _progress[id] = value;

          _emitProgress(id, value);
        },
      );

      final file = DownloadedFile(
        id: id,
        lectureId: lectureId,
        title: title,
        fileType: fileType,
        fileUrl: url,
        localPath: filePath,
        downloadedAt: DateTime.now(),
      );

      await _saveDownloadedFile(file);

      _progress[id] = 1.0;

      _emitProgress(id, 1.0);

      return file;
    } catch (e) {
      _progress.remove(id);

      _controllers[id]?.addError(e);

      rethrow;
    }
  }

  // ===========================================================================
  // OPEN FILE
  // ===========================================================================

  Future<bool> fileExists(
    DownloadedFile file,
  ) async {
    return File(file.localPath).exists();
  }

  // ===========================================================================
  // GET DOWNLOADED FILES
  // ===========================================================================

  Future<List<DownloadedFile>> getDownloadedFiles() async {
    final metadataFile = await _metadataFile();

    if (!await metadataFile.exists()) {
      return [];
    }

    try {
      final content = await metadataFile.readAsString();

      if (content.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(content);

      if (decoded is! List) {
        return [];
      }

      final files = decoded
          .map(
            (item) => DownloadedFile.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (file) => File(file.localPath).existsSync(),
          )
          .toList();

      return files.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // DELETE DOWNLOAD
  // ===========================================================================

  Future<void> deleteDownloadedFile(
    DownloadedFile file,
  ) async {
    final localFile = File(file.localPath);

    if (await localFile.exists()) {
      await localFile.delete();
    }

    final files = await getDownloadedFiles();

    files.removeWhere(
      (item) => item.id == file.id,
    );

    await _writeMetadata(files);
  }

  // ===========================================================================
  // CHECK IF DOWNLOADED
  // ===========================================================================

  Future<DownloadedFile?> findDownloadedFile(
    String id,
  ) async {
    final files = await getDownloadedFiles();

    for (final file in files) {
      if (file.id == id) {
        return file;
      }
    }

    return null;
  }

  // ===========================================================================
  // DIRECTORY
  // ===========================================================================

  Future<Directory> _downloadDirectory() async {
    final baseDirectory =
        await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${baseDirectory.path}/MediData/Downloads',
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  // ===========================================================================
  // METADATA FILE
  // ===========================================================================

  Future<File> _metadataFile() async {
    final directory = await _downloadDirectory();

    return File(
      '${directory.path}/$_metadataFileName',
    );
  }

  // ===========================================================================
  // SAVE METADATA
  // ===========================================================================

  Future<void> _saveDownloadedFile(
    DownloadedFile file,
  ) async {
    final files = await getDownloadedFiles();

    files.removeWhere(
      (item) => item.id == file.id,
    );

    files.add(file);

    await _writeMetadata(files);
  }

  Future<void> _writeMetadata(
    List<DownloadedFile> files,
  ) async {
    final metadataFile = await _metadataFile();

    final data = files
        .map(
          (file) => file.toJson(),
        )
        .toList();

    await metadataFile.writeAsString(
      jsonEncode(data),
    );
  }

  // ===========================================================================
  // PROGRESS
  // ===========================================================================

  void _emitProgress(
    String id,
    double value,
  ) {
    final controller = _controllers[id];

    if (controller != null &&
        !controller.isClosed) {
      controller.add(value);
    }
  }

  // ===========================================================================
  // FILE EXTENSION
  // ===========================================================================

  String _extensionForType(
    String type,
    String url,
  ) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'pdf';

      case 'audio':
        return _extensionFromUrl(
              url,
            ) ??
            'mp3';

      case 'video':
        return _extensionFromUrl(
              url,
            ) ??
            'mp4';

      default:
        return _extensionFromUrl(
              url,
            ) ??
            '';
    }
  }

  String? _extensionFromUrl(
    String url,
  ) {
    try {
      final uri = Uri.parse(url);

      final path = uri.path;

      final dotIndex = path.lastIndexOf('.');

      if (dotIndex == -1) {
        return null;
      }

      final extension = path
          .substring(dotIndex + 1)
          .toLowerCase();

      if (extension.length > 5) {
        return null;
      }

      return extension;
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // SAFE FILE NAME
  // ===========================================================================

  String _sanitizeFileName(
    String value,
  ) {
    final sanitized = value
        .trim()
        .replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        );

    if (sanitized.isEmpty) {
      return 'MediData_File';
    }

    return sanitized;
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  void disposeProgress(
    String id,
  ) {
    _progress.remove(id);

    final controller = _controllers.remove(id);

    controller?.close();
  }
}