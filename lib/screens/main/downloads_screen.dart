import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../models/downloaded_file.dart';
import '../../services/download_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
  });

  @override
  State<DownloadsScreen> createState() =>
      _DownloadsScreenState();
}

class _DownloadsScreenState
    extends State<DownloadsScreen> {
  final DownloadService _downloadService =
      DownloadService.instance;

  late Future<List<DownloadedFile>>
      _filesFuture;

  @override
  void initState() {
    super.initState();

    _filesFuture =
        _downloadService.getDownloadedFiles();
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    setState(() {
      _filesFuture =
          _downloadService.getDownloadedFiles();
    });

    await _filesFuture;
  }

  // ===========================================================================
  // OPEN
  // ===========================================================================

  Future<void> _openFile(
    DownloadedFile file,
  ) async {
    final exists =
        await File(file.localPath).exists();

    if (!exists) {
      await _refresh();
      return;
    }

    await OpenFilex.open(
      file.localPath,
    );
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> _deleteFile(
    DownloadedFile file,
  ) async {
    await _downloadService.deleteDownloadedFile(
      file,
    );

    await _refresh();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.sizeOf(context);

    final isTablet =
        size.shortestSide >= 600;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<DownloadedFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
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
            return const _EmptyDownloads();
          }

          return ListView.separated(
            physics:
                const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              isTablet ? 32 : 18,
              isTablet ? 24 : 18,
              isTablet ? 32 : 18,
              isTablet ? 120 : 105,
            ),
            itemCount: files.length,
            separatorBuilder: (_, _) {
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder: (context, index) {
              final file = files[index];

              return _DownloadedFileTile(
                file: file,
                isTablet: isTablet,
                onOpen: () => _openFile(file),
                onDelete: () => _deleteFile(file),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// FILE TILE
// ============================================================================

class _DownloadedFileTile
    extends StatelessWidget {
  final DownloadedFile file;
  final bool isTablet;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DownloadedFileTile({
    required this.file,
    required this.isTablet,
    required this.onOpen,
    required this.onDelete,
  });

  IconData get _icon {
    switch (file.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;

      case 'audio':
        return Icons.headphones_rounded;

      case 'video':
        return Icons.video_library_rounded;

      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius:
          BorderRadius.circular(
        isTablet ? 20 : 17,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          isTablet ? 20 : 17,
        ),
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.all(
            isTablet ? 18 : 14,
          ),
          child: Row(
            children: [
              Container(
                width: isTablet ? 58 : 50,
                height: isTablet ? 58 : 50,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary
                      .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  _icon,
                  color:
                      theme.colorScheme.primary,
                  size: isTablet ? 29 : 25,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.title,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            isTablet ? 16 : 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      file.fileType
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize:
                            isTablet ? 12 : 10,
                        fontWeight:
                            FontWeight.w600,
                        color: theme
                            .colorScheme
                            .onSurface
                            .withValues(
                              alpha: 0.50,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: onOpen,
                icon: const Icon(
                  Icons.open_in_new_rounded,
                ),
              ),

              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color:
                      theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY
// ============================================================================

class _EmptyDownloads
    extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height:
              MediaQuery.sizeOf(context).height *
                  0.65,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(30),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 65,
                    color: theme
                        .colorScheme
                        .onSurface
                        .withValues(
                          alpha: 0.25,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Downloads',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Downloaded lectures and files will appear here.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
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
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _ErrorState
    extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(
          Icons.refresh_rounded,
        ),
        label: const Text(
          'Try Again',
        ),
      ),
    );
  }
}