import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LectureContentScreen extends StatefulWidget {
  final String lectureId;
  final String lectureTitle;

  const LectureContentScreen({
    super.key,
    required this.lectureId,
    required this.lectureTitle,
  });

  @override
  State<LectureContentScreen> createState() =>
      _LectureContentScreenState();
}

class _LectureContentScreenState
    extends State<LectureContentScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  late Future<List<LectureFile>> _filesFuture;

  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloading = {};
  final Map<String, String> _downloadedFiles = {};

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadFiles();
  }

  // ==========================================================================
  // LOAD FILES
  // ==========================================================================

  Future<List<LectureFile>> _loadFiles() async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          '''
          id,
          lecture_id,
          title,
          file_type,
          file_url,
          display_order,
          is_active,
          created_at,
          updated_at
          ''',
        )
        .eq(
          'lecture_id',
          widget.lectureId,
        )
        .eq(
          'is_active',
          true,
        )
        .order(
          'display_order',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => LectureFile.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    setState(() {
      _filesFuture = _loadFiles();
    });

    await _filesFuture;
  }

  // ==========================================================================
  // BUCKET
  // ==========================================================================

  String _bucketForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'Lecture pdfs';

      case 'audio':
        return 'Lecture audios';

      case 'video':
        return 'lecture videos';

      default:
        throw Exception(
          'Unsupported file type: $type',
        );
    }
  }

  // ==========================================================================
  // EXTRACT STORAGE PATH
  // ==========================================================================

  String _extractStoragePath(
    String value,
    String bucket,
  ) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    // Already a storage path.
    if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);

    if (uri == null) {
      return trimmed;
    }

    final segments = uri.pathSegments;

    final bucketIndex = segments.indexWhere(
      (segment) =>
          Uri.decodeComponent(segment) == bucket,
    );

    if (bucketIndex == -1) {
      throw Exception(
        'Bucket "$bucket" was not found in file URL.',
      );
    }

    if (bucketIndex + 1 >= segments.length) {
      return '';
    }

    return segments
        .sublist(bucketIndex + 1)
        .map(Uri.decodeComponent)
        .join('/');
  }

  // ==========================================================================
  // SIGNED URL
  // ==========================================================================

  Future<String> _createSignedUrl(
    LectureFile file,
  ) async {
    final bucket = _bucketForType(
      file.fileType,
    );

    final path = _extractStoragePath(
      file.fileUrl,
      bucket,
    );

    if (path.isEmpty) {
      throw Exception(
        'Invalid storage path.',
      );
    }

    return _supabase.storage
        .from(bucket)
        .createSignedUrl(
          path,
          3600,
        );
  }

  // ==========================================================================
  // OPEN ONLINE
  // ==========================================================================

  Future<void> _openOnline(
    LectureFile file,
  ) async {
    try {
      final url = await _createSignedUrl(file);

      if (!mounted) return;

      // سيتم ربطه لاحقًا بصفحات الـ PDF / Video / Audio
      // حاليًا نفتح الرابط باستخدام المتصفح.
      await _showOnlineDialog(
        file,
        url,
      );
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Unable to open file.\n$e',
      );
    }
  }

  // ==========================================================================
  // ONLINE DIALOG
  // ==========================================================================

  Future<void> _showOnlineDialog(
    LectureFile file,
    String url,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            file.title,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconForType(file.fileType),
                size: 55,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Online viewing will use this secure signed URL.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SelectableText(
                url,
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // DOWNLOAD
  // ==========================================================================

  Future<void> _downloadFile(
    LectureFile file,
  ) async {
    if (_downloading.contains(file.id)) {
      return;
    }

    try {
      setState(() {
        _downloading.add(file.id);
        _downloadProgress[file.id] = 0;
      });

      final url = await _createSignedUrl(file);

      final request = http.Request(
        'GET',
        Uri.parse(url),
      );

      final response =
          await request.send();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Download failed (${response.statusCode})',
        );
      }

      final contentLength =
          response.contentLength;

      final directory =
          await getApplicationDocumentsDirectory();

      final downloadsDirectory =
          Directory(
        '${directory.path}/downloads',
      );

      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(
          recursive: true,
        );
      }

      final fileName =
          _safeFileName(
        file.title,
        file.fileType,
      );

      final localFile = File(
        '${downloadsDirectory.path}/$fileName',
      );

      final sink =
          localFile.openWrite();

      int received = 0;

      await for (final chunk
          in response.stream) {
        received += chunk.length;

        sink.add(chunk);

        if (contentLength != null &&
            contentLength > 0 &&
            mounted) {
          setState(() {
            _downloadProgress[file.id] =
                received / contentLength;
          });
        }
      }

      await sink.flush();
      await sink.close();

      if (!mounted) return;

      setState(() {
        _downloading.remove(file.id);
        _downloadProgress[file.id] = 1.0;
        _downloadedFiles[file.id] =
            localFile.path;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${file.title} downloaded successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _downloading.remove(file.id);
        _downloadProgress.remove(file.id);
      });

      _showError(
        'Download failed.\n$e',
      );
    }
  }

  // ==========================================================================
  // FILE NAME
  // ==========================================================================

  String _safeFileName(
    String title,
    String type,
  ) {
    String clean = title.trim();

    if (clean.isEmpty) {
      clean = 'lecture_file';
    }

    clean = clean.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    final extension =
        _extensionForType(type);

    if (!clean.toLowerCase().endsWith(
          '.$extension',
        )) {
      clean = '$clean.$extension';
    }

    return clean;
  }

  String _extensionForType(
    String type,
  ) {
    switch (type.toLowerCase()) {
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
  // ICON
  // ==========================================================================

  IconData _iconForType(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;

      case 'audio':
        return Icons.headphones_rounded;

      case 'video':
        return Icons.play_circle_fill_rounded;

      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  // ==========================================================================
  // TYPE COLOR
  // ==========================================================================

  Color _colorForType(
    BuildContext context,
    String type,
  ) {
    final theme =
        Theme.of(context);

    switch (type.toLowerCase()) {
      case 'pdf':
        return theme.colorScheme.error;

      case 'audio':
        return Colors.orange;

      case 'video':
        return theme.colorScheme.primary;

      default:
        return theme.colorScheme.secondary;
    }
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final size =
        MediaQuery.sizeOf(context);

    final isTablet =
        size.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lectureTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),

      body: FutureBuilder<List<LectureFile>>(
        future: _filesFuture,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              onRetry: _refresh,
            );
          }

          final files =
              snapshot.data ?? [];

          if (files.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics:
                  const AlwaysScrollableScrollPhysics(
                parent:
                    BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                isTablet ? 32 : 18,
                isTablet ? 28 : 18,
                isTablet ? 32 : 18,
                isTablet ? 45 : 30,
              ),
              itemCount: files.length,
              separatorBuilder: (
                _,
                _,
              ) =>
                  SizedBox(
                height:
                    isTablet ? 14 : 10,
              ),
              itemBuilder: (
                context,
                index,
              ) {
                final file =
                    files[index];

                return _ContentTile(
                  file: file,
                  isTablet: isTablet,
                  downloading:
                      _downloading
                          .contains(file.id),
                  progress:
                      _downloadProgress[
                          file.id],
                  downloaded:
                      _downloadedFiles
                          .containsKey(file.id),
                  onOpenOnline: () =>
                      _openOnline(file),
                  onDownload: () =>
                      _downloadFile(file),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// CONTENT TILE
// ============================================================================

class _ContentTile extends StatelessWidget {
  final LectureFile file;
  final bool isTablet;
  final bool downloading;
  final bool downloaded;
  final double? progress;

  final VoidCallback onOpenOnline;
  final VoidCallback onDownload;

  const _ContentTile({
    required this.file,
    required this.isTablet,
    required this.downloading,
    required this.downloaded,
    required this.progress,
    required this.onOpenOnline,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final typeColor =
        _typeColor(
      context,
      file.fileType,
    );

    return Material(
      color:
          theme.colorScheme.surface,
      borderRadius:
          BorderRadius.circular(
        isTablet ? 22 : 18,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap:
            downloading
                ? null
                : onOpenOnline,
        child: Container(
          padding:
              EdgeInsets.all(
            isTablet ? 18 : 14,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              isTablet ? 22 : 18,
            ),
            border:
                Border.all(
              color: theme
                  .colorScheme
                  .onSurface
                  .withValues(
                alpha: 0.06,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha:
                      theme.brightness ==
                              Brightness.dark
                          ? 0.20
                          : 0.05,
                ),
                blurRadius: 12,
                offset:
                    const Offset(0, 4),
              ),
            ],
          ),
          child:
              Column(
            children: [
              Row(
                children: [
                  // ==========================================================
                  // ICON
                  // ==========================================================

                  Container(
                    width:
                        isTablet
                            ? 60
                            : 50,
                    height:
                        isTablet
                            ? 60
                            : 50,
                    decoration:
                        BoxDecoration(
                      color: typeColor
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        isTablet
                            ? 17
                            : 14,
                      ),
                    ),
                    child:
                        Icon(
                      _iconForType(
                        file.fileType,
                      ),
                      color:
                          typeColor,
                      size:
                          isTablet
                              ? 30
                              : 27,
                    ),
                  ),

                  SizedBox(
                    width:
                        isTablet
                            ? 16
                            : 13,
                  ),

                  // ==========================================================
                  // TITLE
                  // ==========================================================

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          file.title,
                          maxLines:
                              2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              TextStyle(
                            fontSize:
                                isTablet
                                    ? 18
                                    : 16,
                            fontWeight:
                                FontWeight
                                    .w700,
                            color: theme
                                .colorScheme
                                .onSurface,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Text(
                          file.fileType
                              .toUpperCase(),
                          style:
                              TextStyle(
                            fontSize:
                                isTablet
                                    ? 12
                                    : 11,
                            fontWeight:
                                FontWeight
                                    .w600,
                            color:
                                typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==========================================================
                  // ONLINE
                  // ==========================================================

                  IconButton(
                    tooltip:
                        'Open Online',
                    onPressed:
                        downloading
                            ? null
                            : onOpenOnline,
                    icon:
                        const Icon(
                      Icons
                          .open_in_new_rounded,
                    ),
                  ),

                  // ==========================================================
                  // DOWNLOAD
                  // ==========================================================

                  if (downloaded &&
                      !downloading)
                    Icon(
                      Icons
                          .check_circle_rounded,
                      color:
                          Colors.green,
                      size:
                          isTablet
                              ? 29
                              : 25,
                    )
                  else
                    IconButton(
                      tooltip:
                          'Download',
                      onPressed:
                          downloading
                              ? null
                              : onDownload,
                      icon:
                          const Icon(
                        Icons
                            .download_rounded,
                      ),
                    ),
                ],
              ),

              // ==============================================================
              // DOWNLOAD PROGRESS
              // ==============================================================

              if (downloading) ...[
                const SizedBox(
                  height: 12,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          LinearProgressIndicator(
                        value:
                            progress,
                        minHeight:
                            5,
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      progress !=
                              null
                          ? '${(progress! * 100).toInt()}%'
                          : '...',
                      style:
                          TextStyle(
                        fontSize:
                            12,
                        fontWeight:
                            FontWeight
                                .w600,
                        color: theme
                            .colorScheme
                            .primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(
    BuildContext context,
    String type,
  ) {
    final theme =
        Theme.of(context);

    switch (type.toLowerCase()) {
      case 'pdf':
        return theme
            .colorScheme
            .error;

      case 'audio':
        return Colors.orange;

      case 'video':
        return theme
            .colorScheme
            .primary;

      default:
        return theme
            .colorScheme
            .secondary;
    }
  }

  IconData _iconForType(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons
            .picture_as_pdf_rounded;

      case 'audio':
        return Icons
            .headphones_rounded;

      case 'video':
        return Icons
            .play_circle_fill_rounded;

      default:
        return Icons
            .insert_drive_file_rounded;
    }
  }
}

// ============================================================================
// MODEL
// ============================================================================

class LectureFile {
  final String id;
  final String lectureId;
  final String title;
  final String fileType;
  final String fileUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LectureFile({
    required this.id,
    required this.lectureId,
    required this.title,
    required this.fileType,
    required this.fileUrl,
    required this.displayOrder,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory LectureFile.fromMap(
    Map<String, dynamic> map,
  ) {
    return LectureFile(
      id: map['id']?.toString() ?? '',
      lectureId:
          map['lecture_id']?.toString() ?? '',
      title:
          map['title']?.toString() ?? '',
      fileType:
          map['file_type']?.toString() ?? '',
      fileUrl:
          map['file_url']?.toString() ?? '',
      displayOrder:
          (map['display_order'] as num?)
                  ?.toInt() ??
              0,
      isActive:
          map['is_active'] as bool? ??
              true,
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(
                  map['created_at']
                      .toString(),
                )
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(
                  map['updated_at']
                      .toString(),
                )
              : null,
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState
    extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .folder_off_outlined,
              size: 65,
              color: theme
                  .colorScheme
                  .onSurface
                  .withValues(
                alpha: 0.30,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'No Content Available',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
                color: theme
                    .colorScheme
                    .onSurface,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'This lecture does not have any available files.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme
                    .colorScheme
                    .onSurface
                    .withValues(
                  alpha: 0.60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================

class _ErrorState
    extends StatelessWidget {
  final Future<void>
      Function() onRetry;

  const _ErrorState({
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .cloud_off_rounded,
              size: 60,
              color: theme
                  .colorScheme
                  .error,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Unable to load content',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
                color: theme
                    .colorScheme
                    .onSurface,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Please check your internet connection and try again.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 13,
                color: theme
                    .colorScheme
                    .onSurface
                    .withValues(
                  alpha: 0.60,
                ),
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
                  const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}