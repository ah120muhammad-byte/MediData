import 'package:flutter/material.dart';
import '../../services/download_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DownloadsService _service = DownloadsService.instance;

  List<DownloadItem> _downloads = [];

  String _search = '';

  bool _isLoading = true;

  List<DownloadItem> _allVisibleDownloads(List<DownloadItem> active) {
    final completedIds = _downloads.map((item) => item.id).toSet();

    final visibleActive = active.where(
      (item) => !completedIds.contains(item.id),
    );

    final result = <DownloadItem>[...visibleActive, ..._downloads];

    result.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

    return result;
  }

  @override
  void initState() {
    super.initState();

    _loadDownloads();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> _loadDownloads() async {
    try {
      final downloads = await _service.getDownloads();

      if (!mounted) {
        return;
      }

      setState(() {
        _downloads = downloads;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load downloads error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showError('Unable to load downloads.');
    }
  }

  // ===========================================================================
  // FILTER
  // ===========================================================================

  Map<String, List<DownloadItem>> _groupDownloads(
    List<DownloadItem> visibleDownloads,
  ) {
    final query = _search.trim().toLowerCase();

    final filtered = query.isEmpty
        ? visibleDownloads
        : visibleDownloads.where((item) {
            return item.title.toLowerCase().contains(query) ||
                item.lectureTitle.toLowerCase().contains(query) ||
                item.fileType.toLowerCase().contains(query);
          }).toList();

    final grouped = <String, List<DownloadItem>>{};

    for (final item in filtered) {
      final key = item.lectureId.isEmpty ? item.lectureTitle : item.lectureId;

      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped;
  }

  // ===========================================================================
  // OPEN
  // ===========================================================================

  Future<void> _openFile(DownloadItem item) async {
    try {
      await _service.open(item);
    } catch (e) {
      debugPrint('Open download error: $e');

      if (!mounted) {
        return;
      }

      _showError('Unable to open this file.');

      await _loadDownloads();
    }
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> _deleteFile(DownloadItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete download?'),
          content: Text('Remove "${item.title}" from this device?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _service.delete(item.id);

      await _loadDownloads();
    } catch (e) {
      debugPrint('Delete download error: $e');

      if (!mounted) {
        return;
      }

      _showError('Unable to delete this file.');
    }
  }

  // ===========================================================================
  // DELETE ALL
  // ===========================================================================

  Future<void> _deleteAll() async {
    if (_downloads.isEmpty) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete all downloads?'),
          content: const Text(
            'All downloaded lecture files will be removed from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _service.deleteAll();

    await _loadDownloads();
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final isTablet = size.shortestSide >= 600;

    final maxWidth = isTablet ? 900.0 : 700.0;

    return Column(
      children: [
        // =====================================================================
        // HEADER
        // =====================================================================
        Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 32 : 18,
            isTablet ? 18 : 12,
            isTablet ? 32 : 18,
            4,
          ),
          child: Row(
            children: [
              Icon(
                Icons.download_rounded,
                size: isTablet ? 28 : 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Downloads',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (_downloads.isNotEmpty)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete_all') {
                      _deleteAll();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete_all',
                      child: Text('Delete all'),
                    ),
                  ],
                ),
              IconButton(
                onPressed: _loadDownloads,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),

        // =====================================================================
        // SEARCH
        // =====================================================================
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 32 : 16,
                8,
                isTablet ? 32 : 16,
                8,
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search downloads...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              _search = '';
                            });
                          },
                          icon: const Icon(Icons.clear_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),

        // =====================================================================
        // CONTENT
        // =====================================================================
        Expanded(
          child: ValueListenableBuilder<List<DownloadItem>>(
            valueListenable: _service.activeDownloadItemsNotifier,
            builder: (context, activeDownloads, _) {
              return ValueListenableBuilder<Map<String, double>>(
                valueListenable: _service.progressNotifier,
                builder: (context, progressMap, _) {
                  if (_isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final visibleDownloads = _allVisibleDownloads(
                    activeDownloads,
                  );

                  final grouped = _groupDownloads(visibleDownloads);

                  if (grouped.isEmpty) {
                    return _buildEmptyState(context, isTablet);
                  }

                  final entries = grouped.entries.toList();

                  return RefreshIndicator(
                    onRefresh: _loadDownloads,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 32 : 16,
                            12,
                            isTablet ? 32 : 16,
                            125,
                          ),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final lectureItems = entries[index].value;

                            return _LectureDownloadGroup(
                              lectureTitle: lectureItems.first.lectureTitle,
                              items: lectureItems,
                              progressMap: progressMap,
                              onOpen: _openFile,
                              onDelete: _deleteFile,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // EMPTY
  // ===========================================================================

  Widget _buildEmptyState(BuildContext context, bool isTablet) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_outlined,
                  size: isTablet ? 70 : 60,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 16),
                Text(
                  _search.isEmpty
                      ? 'No Downloads Yet'
                      : 'No Matching Downloads',
                  style: TextStyle(
                    fontSize: isTablet ? 23 : 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _search.isEmpty
                      ? 'Downloaded lecture files will appear here.'
                      : 'Try another search term.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// LECTURE GROUP
// ============================================================================

class _LectureDownloadGroup extends StatelessWidget {
  final String lectureTitle;
  final List<DownloadItem> items;
  final Map<String, double> progressMap;
  final ValueChanged<DownloadItem> onOpen;
  final ValueChanged<DownloadItem> onDelete;

  const _LectureDownloadGroup({
    required this.lectureTitle,
    required this.items,
    required this.progressMap,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final downloadingCount = items.where((item) {
      final progress = progressMap[item.id];
      return progress != null && progress < 1.0;
    }).length;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 10,
          ),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),

          // ---------------------------------------------------------------
          // LECTURE HEADER
          // ---------------------------------------------------------------
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: theme.colorScheme.primary,
            ),
          ),

          title: Text(
            lectureTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),

          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(
                  '${items.length} '
                  '${items.length == 1 ? 'file' : 'files'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),

                if (downloadingCount > 0) ...[
                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$downloadingCount downloading',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          children: [
            ...items.map((item) {
              final progress = progressMap[item.id];

              return _DownloadListTile(
                item: item,
                progress: progress,
                onOpen: () => onOpen(item),
                onDelete: () => onDelete(item),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DOWNLOAD LIST TILE
// ============================================================================

class _DownloadListTile
    extends StatelessWidget {
  final DownloadItem item;
  final double? progress;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DownloadListTile({
    required this.item,
    required this.progress,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final downloading =
        progress != null &&
            progress! < 1.0;

    final percent =
        ((progress ?? 0) * 100).round();

    return Padding(
      padding:
          const EdgeInsets.only(
        top: 2,
        bottom: 2,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 3,
        ),

        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            color: theme
                .colorScheme
                .primary
                .withValues(
              alpha: 0.09,
            ),
          ),
          child: Icon(
            _iconForType(
              item.fileType,
            ),
            color:
                theme.colorScheme.primary,
          ),
        ),

        title: Text(
          item.title,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight:
                FontWeight.w700,
            fontSize: 14,
          ),
        ),

        subtitle: downloading
            ? Padding(
                padding:
                    const EdgeInsets.only(
                  top: 7,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      'Downloading... $percent%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w700,
                        color: theme
                            .colorScheme
                            .primary,
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                '${_labelForType(item.fileType)} • '
                '${DownloadsService.formatBytes(item.sizeBytes)}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme
                      .colorScheme
                      .onSurface
                      .withValues(
                    alpha: 0.55,
                  ),
                ),
              ),

        trailing: downloading
            ? SizedBox(
                width: 28,
                height: 28,
                child:
                    CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                ),
              )
            : PopupMenuButton<String>(
                onSelected:
                    (value) {
                  if (value == 'open') {
                    onOpen();
                  } else if (value ==
                      'delete') {
                    onDelete();
                  }
                },
                itemBuilder:
                    (_) => const [
                  PopupMenuItem(
                    value: 'open',
                    child:
                        Text('Open'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Delete'),
                  ),
                ],
              ),
      ),
    );
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
            .audio_file_rounded;

      case 'video':
        return Icons
            .video_file_rounded;

      default:
        return Icons
            .insert_drive_file_rounded;
    }
  }

  String _labelForType(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'PDF';

      case 'audio':
        return 'Audio';

      case 'video':
        return 'Video';

      default:
        return 'File';
    }
  }
}