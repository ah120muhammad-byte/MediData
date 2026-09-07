import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';
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

  Future<void> _loadDownloads() async {
    try {
      final downloads = await _service.getDownloads();

      if (!mounted) return;

      setState(() {
        _downloads = downloads;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load downloads error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Unable to load downloads.');
    }
  }

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

  Future<void> _openFile(DownloadItem item) async {
    try {
      await _service.open(item);
    } catch (e) {
      debugPrint('Open download error: $e');

      if (!mounted) return;

      _showError('Unable to open this file.');
      await _loadDownloads();
    }
  }

  Future<void> _deleteFile(DownloadItem item) async {
    if (!mounted) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete download?'),
          content: Text('Remove "${item.title}" from this device?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) return;

    try {
      await _service.delete(item.id);

      if (!mounted) return;
      await _loadDownloads();
    } catch (e) {
      debugPrint('Delete download error: $e');

      if (!mounted) return;
      _showError('Unable to delete this file.');
    }
  }

  Future<void> _deleteAll() async {
    if (_downloads.isEmpty || !mounted) return;

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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) return;

    try {
      await _service.deleteAll();

      if (!mounted) return;
      await _loadDownloads();
    } catch (e) {
      debugPrint('Delete all downloads error: $e');

      if (!mounted) return;
      _showError('Unable to delete all downloads.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final horizontalPadding = Responsive.horizontalPadding(context);
    final contentMaxWidth = Responsive.width(context) >= 1000 ? 920.0 : 720.0;

    return ValueListenableBuilder<List<DownloadItem>>(
      valueListenable: _service.activeDownloadItemsNotifier,
      builder: (context, activeDownloads, _) {
        return ValueListenableBuilder<Map<String, double>>(
          valueListenable: _service.progressNotifier,
          builder: (context, progressMap, _) {
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final visibleDownloads = _allVisibleDownloads(activeDownloads);
            final grouped = _groupDownloads(visibleDownloads);
            final entries = grouped.entries.toList();

            return RefreshIndicator(
              onRefresh: _loadDownloads,
              color: scheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      4,
                      horizontalPadding,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: contentMaxWidth),
                          child: _DownloadsHeader(
                            hasDownloads: _downloads.isNotEmpty,
                            onDeleteAll: _deleteAll,
                            onRefresh: _loadDownloads,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      4,
                      horizontalPadding,
                      4,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: contentMaxWidth),
                          child: TextField(
                            onChanged: (value) {
                              setState(() => _search = value);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search downloads...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _search.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () => setState(() => _search = ''),
                                      icon: const Icon(Icons.clear_rounded),
                                    )
                                  : null,
                              filled: true,
                              fillColor: scheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.cardRadius(context),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.cardRadius(context),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.cardRadius(context),
                                ),
                                borderSide: BorderSide(
                                  color: scheme.primary,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (entries.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        8,
                        horizontalPadding,
                        16,
                      ),
                      sliver: SliverList.separated(
                        itemCount: entries.length,
                        separatorBuilder: (context, index) => SizedBox(
                          height: Responsive.spacing(
                            context,
                            base: 12,
                            min: 8,
                            max: 18,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final lectureItems = entries[index].value;
                          return Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: contentMaxWidth),
                              child: _LectureDownloadGroup(
                                lectureTitle: lectureItems.first.lectureTitle,
                                items: lectureItems,
                                progressMap: progressMap,
                                onOpen: _openFile,
                                onDelete: _deleteFile,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSearching = _search.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          12,
          Responsive.horizontalPadding(context),
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.download_rounded,
                size: 36,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No Matching Downloads' : 'No Downloads Yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try another search term.'
                  : 'Downloaded lecture files will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadsHeader extends StatelessWidget {
  final bool hasDownloads;
  final VoidCallback onDeleteAll;
  final VoidCallback onRefresh;

  const _DownloadsHeader({
    required this.hasDownloads,
    required this.onDeleteAll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.download_rounded,
            color: scheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Downloads',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                hasDownloads
                    ? 'Your saved lecture files'
                    : 'Files saved on this device',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
        if (hasDownloads)
          PopupMenuButton<String>(
            tooltip: 'Download options',
            onSelected: (value) {
              if (value == 'delete_all') onDeleteAll();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete_all',
                child: Text('Delete all'),
              ),
            ],
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

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
    final scheme = theme.colorScheme;
    final downloadingCount = items.where((item) {
      final progress = progressMap[item.id];
      return progress != null && progress < 1.0;
    }).length;

    final radius = Responsive.cardRadius(context);
    final tileHorizontal = Responsive.cardPadding(context);
    final iconContainer = Responsive.clamped(
      context,
      base: 46,
      min: 40,
      max: 54,
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: tileHorizontal,
            vertical: 4,
          ),
          childrenPadding: EdgeInsets.fromLTRB(12, 0, 12, 10),
          leading: Container(
            width: iconContainer,
            height: iconContainer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.10),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: scheme.primary,
              size: 22,
            ),
          ),
          title: Text(
            lectureTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(
                  '${items.length} ${items.length == 1 ? 'file' : 'files'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                if (downloadingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$downloadingCount downloading',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          children: [
            ...items.map(
              (item) {
                final progress = progressMap[item.id];
                return _DownloadListTile(
                  item: item,
                  progress: progress,
                  onOpen: () => onOpen(item),
                  onDelete: () => onDelete(item),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadListTile extends StatelessWidget {
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final downloading = progress != null && progress! < 1.0;
    final percent = ((progress ?? 0) * 100).round();
    final iconContainer = Responsive.clamped(
      context,
      base: 44,
      min: 40,
      max: 54,
    );
    final radius = Responsive.smallRadius(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          width: iconContainer,
          height: iconContainer,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: scheme.primary.withValues(alpha: 0.09),
          ),
          child: Icon(
            _iconForType(item.fileType),
            color: scheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: downloading
            ? Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Downloading... $percent%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                '${_labelForType(item.fileType)} • ${DownloadsService.formatBytes(item.sizeBytes)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
        trailing: downloading
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                ),
              )
            : PopupMenuButton<String>(
                tooltip: 'File options',
                onSelected: (value) {
                  if (value == 'open') {
                    onOpen();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'open',
                    child: Text('Open'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'audio':
        return Icons.audio_file_rounded;
      case 'video':
        return Icons.video_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _labelForType(String type) {
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
