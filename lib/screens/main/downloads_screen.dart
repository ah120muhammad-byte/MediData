import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';
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
  final DownloadsService _service =
      DownloadsService.instance;

  List<DownloadItem> _downloads = [];

  String _search = '';

  bool _isLoading = true;

  // ==========================================================================
  // COMBINE ACTIVE + COMPLETED
  // ==========================================================================

  List<DownloadItem> _allVisibleDownloads(
    List<DownloadItem> active,
  ) {
    final completedIds =
        _downloads
            .map(
              (item) => item.id,
            )
            .toSet();

    final visibleActive =
        active.where(
      (item) =>
          !completedIds.contains(
        item.id,
      ),
    );

    final result =
        <DownloadItem>[
      ...visibleActive,
      ..._downloads,
    ];

    result.sort(
      (a, b) =>
          b.downloadedAt.compareTo(
        a.downloadedAt,
      ),
    );

    return result;
  }

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _loadDownloads();
  }

  // ==========================================================================
  // LOAD
  // ==========================================================================

  Future<void> _loadDownloads() async {
    try {
      final downloads =
          await _service.getDownloads();

      if (!mounted) {
        return;
      }

      setState(() {
        _downloads = downloads;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'Load downloads error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showError(
        'Unable to load downloads.',
      );
    }
  }

  // ==========================================================================
  // FILTER
  // ==========================================================================

  Map<String, List<DownloadItem>>
      _groupDownloads(
    List<DownloadItem> visibleDownloads,
  ) {
    final query =
        _search.trim().toLowerCase();

    final filtered = query.isEmpty
        ? visibleDownloads
        : visibleDownloads.where(
            (item) {
              return item.title
                      .toLowerCase()
                      .contains(
                        query,
                      ) ||
                  item.lectureTitle
                      .toLowerCase()
                      .contains(
                        query,
                      ) ||
                  item.fileType
                      .toLowerCase()
                      .contains(
                        query,
                      );
            },
          ).toList();

    final grouped =
        <String, List<DownloadItem>>{};

    for (final item in filtered) {
      final key =
          item.lectureId.isEmpty
              ? item.lectureTitle
              : item.lectureId;

      grouped
          .putIfAbsent(
        key,
        () => [],
      )
          .add(item);
    }

    return grouped;
  }

  // ==========================================================================
  // OPEN
  // ==========================================================================

  Future<void> _openFile(
    DownloadItem item,
  ) async {
    try {
      await _service.open(
        item,
      );
    } catch (e) {
      debugPrint(
        'Open download error: $e',
      );

      if (!mounted) {
        return;
      }

      _showError(
        'Unable to open this file.',
      );

      await _loadDownloads();
    }
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  Future<void> _deleteFile(
    DownloadItem item,
  ) async {
    if (!mounted) {
      return;
    }

    final shouldDelete =
        await showDialog<bool>(
      context:
          context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Delete download?',
          ),
          content:
              Text(
            'Remove "${item.title}" from this device?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
                  const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        shouldDelete != true) {
      return;
    }

    try {
      await _service.delete(
        item.id,
      );

      if (!mounted) {
        return;
      }

      await _loadDownloads();
    } catch (e) {
      debugPrint(
        'Delete download error: $e',
      );

      if (!mounted) {
        return;
      }

      _showError(
        'Unable to delete this file.',
      );
    }
  }

  // ==========================================================================
  // DELETE ALL
  // ==========================================================================

  Future<void> _deleteAll() async {
    if (_downloads.isEmpty ||
        !mounted) {
      return;
    }

    final shouldDelete =
        await showDialog<bool>(
      context:
          context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Delete all downloads?',
          ),
          content:
              const Text(
            'All downloaded lecture files will be removed from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
                  const Text(
                'Delete All',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        shouldDelete != true) {
      return;
    }

    try {
      await _service.deleteAll();

      if (!mounted) {
        return;
      }

      await _loadDownloads();
    } catch (e) {
      debugPrint(
        'Delete all downloads error: $e',
      );

      if (!mounted) {
        return;
      }

      _showError(
        'Unable to delete all downloads.',
      );
    }
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(
            message,
          ),
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final horizontalPadding =
        Responsive.horizontalPadding(
      context,
    );

    final topSpacing =
        Responsive.spacing(
      context,
      base:
          12,
      min:
          8,
      max:
          20,
    );

    final sectionSpacing =
        Responsive.spacing(
      context,
      base:
          8,
      min:
          6,
      max:
          14,
    );

    final contentMaxWidth =
        Responsive.width(context) >=
                1000
            ? 920.0
            : 720.0;

    return Column(
      children: [
        // ======================================================================
        // HEADER
        // ======================================================================

        Padding(
          padding:
              EdgeInsets.fromLTRB(
            horizontalPadding,
            topSpacing,
            horizontalPadding,
            4,
          ),
          child:
              Row(
            children: [
              Icon(
                Icons
                    .download_rounded,
                size:
                    Responsive.iconSize(
                  context,
                  base:
                      24,
                  min:
                      21,
                  max:
                      30,
                ),
                color:
                    theme
                        .colorScheme
                        .primary,
              ),

              SizedBox(
                width:
                    Responsive.spacing(
                  context,
                  base:
                      10,
                  min:
                      7,
                  max:
                      14,
                ),
              ),

              Expanded(
                child:
                    Text(
                  'Downloads',
                  style:
                      TextStyle(
                    fontSize:
                        Responsive.titleSize(
                      context,
                      base:
                          20,
                      min:
                          18,
                      max:
                          28,
                    ),
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              if (_downloads.isNotEmpty)
                PopupMenuButton<String>(
                  onSelected:
                      (value) {
                    if (value ==
                        'delete_all') {
                      _deleteAll();
                    }
                  },
                  itemBuilder:
                      (_) =>
                          const [
                    PopupMenuItem(
                      value:
                          'delete_all',
                      child:
                          Text(
                        'Delete all',
                      ),
                    ),
                  ],
                ),

              IconButton(
                tooltip:
                    'Refresh',
                onPressed:
                    _loadDownloads,
                icon:
                    const Icon(
                  Icons
                      .refresh_rounded,
                ),
              ),
            ],
          ),
        ),

        // ======================================================================
        // SEARCH
        // ======================================================================

        Center(
          child:
              ConstrainedBox(
            constraints:
                BoxConstraints(
              maxWidth:
                  contentMaxWidth,
            ),
            child:
                Padding(
              padding:
                  EdgeInsets.fromLTRB(
                horizontalPadding,
                sectionSpacing,
                horizontalPadding,
                sectionSpacing,
              ),
              child:
                  TextField(
                onChanged:
                    (value) {
                  setState(() {
                    _search =
                        value;
                  });
                },
                decoration:
                    InputDecoration(
                  hintText:
                      'Search downloads...',
                  prefixIcon:
                      const Icon(
                    Icons
                        .search_rounded,
                  ),
                  suffixIcon:
                      _search.isNotEmpty
                          ? IconButton(
                              onPressed:
                                  () {
                                setState(
                                  () {
                                    _search =
                                        '';
                                  },
                                );
                              },
                              icon:
                                  const Icon(
                                Icons
                                    .clear_rounded,
                              ),
                            )
                          : null,
                  filled:
                      true,
                  fillColor:
                      theme
                          .colorScheme
                          .surfaceContainerHighest,
                  contentPadding:
                      EdgeInsets.symmetric(
                    horizontal:
                        Responsive.cardPadding(
                      context,
                    ),
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      Responsive.smallRadius(
                        context,
                      ),
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      Responsive.smallRadius(
                        context,
                      ),
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      Responsive.smallRadius(
                        context,
                      ),
                    ),
                    borderSide:
                        BorderSide(
                      color:
                          theme
                              .colorScheme
                              .primary,
                      width:
                          1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ======================================================================
        // CONTENT
        // ======================================================================

        Expanded(
          child:
              ValueListenableBuilder<
                  List<DownloadItem>>(
            valueListenable:
                _service
                    .activeDownloadItemsNotifier,
            builder:
                (
              context,
              activeDownloads,
              _,
            ) {
              return ValueListenableBuilder<
                  Map<String, double>>(
                valueListenable:
                    _service
                        .progressNotifier,
                builder:
                    (
                  context,
                  progressMap,
                  _,
                ) {
                  if (_isLoading) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  final visibleDownloads =
                      _allVisibleDownloads(
                    activeDownloads,
                  );

                  final grouped =
                      _groupDownloads(
                    visibleDownloads,
                  );

                  if (grouped.isEmpty) {
                    return _buildEmptyState(
                      context,
                    );
                  }

                  final entries =
                      grouped.entries.toList();

                  final listPadding =
                      Responsive.scrollBottomPadding(
                    context,
                    base:
                        125,
                  );

                  return RefreshIndicator(
                    onRefresh:
                        _loadDownloads,
                    child:
                        Center(
                      child:
                          ConstrainedBox(
                        constraints:
                            BoxConstraints(
                          maxWidth:
                              contentMaxWidth,
                        ),
                        child:
                            ListView.separated(
                          physics:
                              const AlwaysScrollableScrollPhysics(
                            parent:
                                BouncingScrollPhysics(),
                          ),
                          padding:
                              EdgeInsets.fromLTRB(
                            horizontalPadding,
                            Responsive.spacing(
                              context,
                              base:
                                  12,
                              min:
                                  8,
                              max:
                                  18,
                            ),
                            horizontalPadding,
                            listPadding,
                          ),
                          itemCount:
                              entries.length,
                          separatorBuilder:
                              (
                            _,
                            _,
                          ) {
                            return SizedBox(
                              height:
                                  Responsive.spacing(
                                context,
                                base:
                                    16,
                                min:
                                    10,
                                max:
                                    22,
                              ),
                            );
                          },
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final lectureItems =
                                entries[
                                        index]
                                    .value;

                            return _LectureDownloadGroup(
                              lectureTitle:
                                  lectureItems
                                      .first
                                      .lectureTitle,
                              items:
                                  lectureItems,
                              progressMap:
                                  progressMap,
                              onOpen:
                                  _openFile,
                              onDelete:
                                  _deleteFile,
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

  // ==========================================================================
  // EMPTY
  // ==========================================================================

  Widget _buildEmptyState(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final iconSize =
        Responsive.clamped(
      context,
      base:
          60,
      min:
          52,
      max:
          82,
    );

    final titleSize =
        Responsive.titleSize(
      context,
      base:
          21,
      min:
          18,
      max:
          28,
    );

    final messageSize =
        Responsive.bodyTextSize(
      context,
      base:
          13,
      min:
          12,
      max:
          16,
    );

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(
        parent:
            BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height:
              MediaQuery.sizeOf(
                    context,
                  ).height *
                  0.55,
          child:
              Center(
            child:
                Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal:
                    Responsive.horizontalPadding(
                  context,
                ),
              ),
              child:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .download_outlined,
                    size:
                        iconSize,
                    color:
                        theme
                            .colorScheme
                            .onSurface
                            .withValues(
                      alpha:
                          0.25,
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          16,
                      min:
                          10,
                      max:
                          22,
                    ),
                  ),

                  Text(
                    _search.isEmpty
                        ? 'No Downloads Yet'
                        : 'No Matching Downloads',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          titleSize,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          8,
                      min:
                          6,
                      max:
                          12,
                    ),
                  ),

                  Text(
                    _search.isEmpty
                        ? 'Downloaded lecture files will appear here.'
                        : 'Try another search term.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          messageSize,
                      height:
                          1.4,
                      color:
                          theme
                              .colorScheme
                              .onSurface
                              .withValues(
                        alpha:
                            0.60,
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
// LECTURE GROUP
// ============================================================================

class _LectureDownloadGroup
    extends StatelessWidget {
  final String lectureTitle;

  final List<DownloadItem>
      items;

  final Map<String, double>
      progressMap;

  final ValueChanged<
      DownloadItem> onOpen;

  final ValueChanged<
      DownloadItem> onDelete;

  const _LectureDownloadGroup({
    required this.lectureTitle,
    required this.items,
    required this.progressMap,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final downloadingCount =
        items.where(
      (item) {
        final progress =
            progressMap[item.id];

        return progress != null &&
            progress < 1.0;
      },
    ).length;

    final radius =
        Responsive.cardRadius(
      context,
    );

    final tileHorizontal =
        Responsive.cardPadding(
      context,
    );

    final iconContainer =
        Responsive.clamped(
      context,
      base:
          44,
      min:
          40,
      max:
          56,
    );

    return Card(
      elevation:
          0,
      margin:
          EdgeInsets.zero,
      clipBehavior:
          Clip.antiAlias,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          radius,
        ),
      ),
      child:
          Theme(
        data:
            theme.copyWith(
          dividerColor:
              Colors.transparent,
        ),
        child:
            ExpansionTile(
          tilePadding:
              EdgeInsets.symmetric(
            horizontal:
                tileHorizontal,
            vertical:
                Responsive.spacing(
              context,
              base:
                  4,
              min:
                  2,
              max:
                  8,
            ),
          ),
          childrenPadding:
              EdgeInsets.only(
            left:
                Responsive.spacing(
              context,
              base:
                  12,
              min:
                  8,
              max:
                  18,
            ),
            right:
                Responsive.spacing(
              context,
              base:
                  12,
              min:
                  8,
              max:
                  18,
            ),
            bottom:
                Responsive.spacing(
              context,
              base:
                  10,
              min:
                  8,
              max:
                  16,
            ),
          ),
          shape:
              const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.zero,
          ),
          collapsedShape:
              const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.zero,
          ),

          // ==================================================================
          // HEADER
          // ==================================================================

          leading:
              Container(
            width:
                iconContainer,
            height:
                iconContainer,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  theme
                      .colorScheme
                      .primary
                      .withValues(
                alpha:
                    0.10,
              ),
            ),
            child:
                Icon(
              Icons
                  .menu_book_rounded,
              color:
                  theme
                      .colorScheme
                      .primary,
              size:
                  Responsive.iconSize(
                context,
                base:
                    22,
                min:
                    20,
                max:
                    28,
              ),
            ),
          ),

          title:
              Text(
            lectureTitle,
            maxLines:
                2,
            overflow:
                TextOverflow.ellipsis,
            style:
                TextStyle(
              fontSize:
                  Responsive.bodyTextSize(
                context,
                base:
                    15,
                min:
                    13,
                max:
                    19,
              ),
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          subtitle:
              Padding(
            padding:
                EdgeInsets.only(
              top:
                  Responsive.spacing(
                context,
                base:
                    4,
                min:
                    3,
                max:
                    7,
              ),
            ),
            child:
                Row(
              children: [
                Text(
                  '${items.length} '
                  '${items.length == 1 ? 'file' : 'files'}',
                  style:
                      TextStyle(
                    fontSize:
                        Responsive.smallTextSize(
                      context,
                      base:
                          12,
                      min:
                          10,
                      max:
                          14,
                    ),
                    color:
                        theme
                            .colorScheme
                            .onSurface
                            .withValues(
                      alpha:
                          0.55,
                    ),
                  ),
                ),

                if (downloadingCount >
                    0) ...[
                  SizedBox(
                    width:
                        Responsive.spacing(
                      context,
                      base:
                          8,
                      min:
                          6,
                      max:
                          12,
                    ),
                  ),

                  Container(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal:
                          Responsive.spacing(
                        context,
                        base:
                            7,
                        min:
                            5,
                        max:
                            10,
                      ),
                      vertical:
                          Responsive.spacing(
                        context,
                        base:
                            3,
                        min:
                            2,
                        max:
                            5,
                      ),
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          theme
                              .colorScheme
                              .primary
                              .withValues(
                        alpha:
                            0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child:
                        Text(
                      '$downloadingCount downloading',
                      style:
                          TextStyle(
                        fontSize:
                            Responsive.smallTextSize(
                          context,
                          base:
                              10,
                          min:
                              9,
                          max:
                              12,
                        ),
                        fontWeight:
                            FontWeight
                                .w700,
                        color:
                            theme
                                .colorScheme
                                .primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          children: [
            ...items.map(
              (
                item,
              ) {
                final progress =
                    progressMap[
                        item.id];

                return _DownloadListTile(
                  item:
                      item,
                  progress:
                      progress,
                  onOpen:
                      () =>
                          onOpen(
                    item,
                  ),
                  onDelete:
                      () =>
                          onDelete(
                    item,
                  ),
                );
              },
            ),
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
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final downloading =
        progress != null &&
            progress! < 1.0;

    final percent =
        ((progress ?? 0) * 100)
            .round();

    final iconContainer =
        Responsive.clamped(
      context,
      base:
          46,
      min:
          42,
      max:
          58,
    );

    final radius =
        Responsive.smallRadius(
      context,
    );

    return Padding(
      padding:
          EdgeInsets.symmetric(
        vertical:
            Responsive.spacing(
          context,
          base:
              2,
          min:
              1,
          max:
              4,
        ),
      ),
      child:
          ListTile(
        contentPadding:
            EdgeInsets.symmetric(
          horizontal:
              Responsive.spacing(
            context,
            base:
                4,
            min:
                2,
            max:
                8,
          ),
          vertical:
              Responsive.spacing(
            context,
            base:
                3,
            min:
                2,
            max:
                5,
          ),
        ),

        leading:
            Container(
          width:
              iconContainer,
          height:
              iconContainer,
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              radius,
            ),
            color:
                theme
                    .colorScheme
                    .primary
                    .withValues(
              alpha:
                  0.09,
            ),
          ),
          child:
              Icon(
            _iconForType(
              item.fileType,
            ),
            color:
                theme
                    .colorScheme
                    .primary,
            size:
                Responsive.iconSize(
              context,
              base:
                  23,
              min:
                  20,
              max:
                  30,
            ),
          ),
        ),

        title:
            Text(
          item.title,
          maxLines:
              2,
          overflow:
              TextOverflow.ellipsis,
          style:
              TextStyle(
            fontWeight:
                FontWeight.w700,
            fontSize:
                Responsive.bodyTextSize(
              context,
              base:
                  14,
              min:
                  12,
              max:
                  18,
            ),
          ),
        ),

        subtitle:
            downloading
                ? Padding(
                    padding:
                        EdgeInsets.only(
                      top:
                          Responsive.spacing(
                        context,
                        base:
                            7,
                        min:
                            5,
                        max:
                            10,
                      ),
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        LinearProgressIndicator(
                          value:
                              progress,
                          minHeight:
                              Responsive.clamped(
                            context,
                            base:
                                6,
                            min:
                                5,
                            max:
                                9,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                        SizedBox(
                          height:
                              Responsive.spacing(
                            context,
                            base:
                                6,
                            min:
                                4,
                            max:
                                8,
                          ),
                        ),
                        Text(
                          'Downloading... $percent%',
                          style:
                              TextStyle(
                            fontSize:
                                Responsive.smallTextSize(
                              context,
                              base:
                                  11,
                              min:
                                  10,
                              max:
                                  13,
                            ),
                            fontWeight:
                                FontWeight.w700,
                            color:
                                theme
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
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.smallTextSize(
                        context,
                        base:
                            11,
                        min:
                            10,
                        max:
                            14,
                      ),
                      color:
                          theme
                              .colorScheme
                              .onSurface
                              .withValues(
                        alpha:
                            0.55,
                      ),
                    ),
                  ),

        trailing:
            downloading
                ? SizedBox(
                    width:
                        Responsive.clamped(
                      context,
                      base:
                          28,
                      min:
                          24,
                      max:
                          36,
                    ),
                    height:
                        Responsive.clamped(
                      context,
                      base:
                          28,
                      min:
                          24,
                      max:
                          36,
                    ),
                    child:
                        CircularProgressIndicator(
                      value:
                          progress,
                      strokeWidth:
                          2.5,
                    ),
                  )
                : PopupMenuButton<String>(
                    onSelected:
                        (value) {
                      if (value ==
                          'open') {
                        onOpen();
                      } else if (value ==
                          'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder:
                        (_) =>
                            const [
                      PopupMenuItem(
                        value:
                            'open',
                        child:
                            Text(
                          'Open',
                        ),
                      ),
                      PopupMenuItem(
                        value:
                            'delete',
                        child:
                            Text(
                          'Delete',
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // ==========================================================================
  // ICON
  // ==========================================================================

  IconData _iconForType(
    String type,
  ) {
    switch (
        type.toLowerCase()) {
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

  // ==========================================================================
  // TYPE LABEL
  // ==========================================================================

  String _labelForType(
    String type,
  ) {
    switch (
        type.toLowerCase()) {
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