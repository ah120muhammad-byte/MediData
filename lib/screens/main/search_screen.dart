import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/global_search_service.dart';

class SearchScreen
    extends StatefulWidget {
  final Future<void> Function(
    String lectureId,
  )? onOpenLecture;

  const SearchScreen({
    super.key,
    this.onOpenLecture,
  });

  @override
  State<SearchScreen> createState() =>
      _SearchScreenState();
}

class _SearchScreenState
    extends State<SearchScreen> {
  final GlobalSearchService
      _searchService =
      GlobalSearchService.instance;

  final TextEditingController
      _controller =
      TextEditingController();

  final FocusNode _focusNode =
      FocusNode();

  Timer? _debounce;

  bool _loading = false;

  String _query = '';

  List<GlobalSearchResult>
      _results = [];

  String? _error;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      },
    );
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _debounce?.cancel();

    _controller.dispose();

    _focusNode.dispose();

    super.dispose();
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  void _onSearchChanged(
    String value,
  ) {
    _debounce?.cancel();

    final query =
        value.trim();

    setState(() {
      _query = query;
      _error = null;
    });

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });

      return;
    }

    _debounce = Timer(
      const Duration(
        milliseconds: 400,
      ),
      () {
        unawaited(
          _performSearch(query),
        );
      },
    );
  }

  Future<void> _performSearch(
    String query,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results =
          await _searchService
              .search(query);

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Global search error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error =
            'Unable to search right now.';
      });
    }
  }

  // ===========================================================================
  // OPEN RESULT
  // ===========================================================================

  Future<void> _openResult(
    GlobalSearchResult result,
  ) async {
    if (result.type !=
        SearchResultType.lecture) {
      return;
    }

    final lectureId =
        result.lectureId;

    if (lectureId == null ||
        lectureId.isEmpty) {
      return;
    }

    if (widget.onOpenLecture !=
        null) {
      await widget.onOpenLecture!(
        lectureId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      return;
    }
  }

  // ===========================================================================
  // CLEAR
  // ===========================================================================

  void _clearSearch() {
    _controller.clear();

    setState(() {
      _query = '';
      _results = [];
      _error = null;
    });

    _focusNode.requestFocus();
  }

  // ===========================================================================
  // RESULT ICON
  // ===========================================================================

  IconData _iconForType(
    SearchResultType type,
  ) {
    switch (type) {
      case SearchResultType.level:
        return Icons.school_rounded;

      case SearchResultType.module:
        return Icons.menu_book_rounded;

      case SearchResultType.lecture:
        return Icons.play_lesson_rounded;
    }
  }

  // ===========================================================================
  // RESULT LABEL
  // ===========================================================================

  String _labelForType(
    SearchResultType type,
  ) {
    switch (type) {
      case SearchResultType.level:
        return 'Academic Level';

      case SearchResultType.module:
        return 'Module';

      case SearchResultType.lecture:
        return 'Lecture';
    }
  }

  // ===========================================================================
  // RESULT SUBTITLE
  // ===========================================================================

  String _subtitleForResult(
    GlobalSearchResult result,
  ) {
    switch (result.type) {
      case SearchResultType.level:
        if (result.description !=
                null &&
            result.description!
                .trim()
                .isNotEmpty) {
          return result.description!
              .trim();
        }

        return 'Academic Level';

      case SearchResultType.module:
        final level =
            result.levelName;

        if (level != null &&
            level.isNotEmpty) {
          return '$level • Module';
        }

        return 'Module';

      case SearchResultType.lecture:
        final parts =
            <String>[];

        if (result.levelName !=
                null &&
            result.levelName!
                .isNotEmpty) {
          parts.add(
            result.levelName!,
          );
        }

        if (result.moduleName !=
                null &&
            result.moduleName!
                .isNotEmpty) {
          parts.add(
            result.moduleName!,
          );
        }

        if (parts.isEmpty) {
          return 'Lecture';
        }

        return parts.join(
          ' • ',
        );
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final size =
        MediaQuery.sizeOf(context);

    final isTablet =
        size.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        titleSpacing:
            isTablet ? 20 : 8,
        title:
            TextField(
          controller:
              _controller,
          focusNode:
              _focusNode,
          textInputAction:
              TextInputAction.search,
          onSubmitted:
              (value) {
            final query =
                value.trim();

            if (query.isNotEmpty) {
              unawaited(
                _performSearch(
                  query,
                ),
              );
            }
          },
          onChanged:
              _onSearchChanged,
          decoration:
              InputDecoration(
            hintText:
                'Search levels, modules, lectures...',
            border:
                InputBorder.none,
            suffixIcon:
                _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip:
                            'Clear',
                        onPressed:
                            _clearSearch,
                        icon:
                            const Icon(
                          Icons
                              .clear_rounded,
                        ),
                      ),
          ),
        ),
      ),
      body:
          _buildBody(
        theme,
        isTablet,
      ),
    );
  }

  // ===========================================================================
  // BODY
  // ===========================================================================

  Widget _buildBody(
    ThemeData theme,
    bool isTablet,
  ) {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _ErrorState(
        message:
            _error!,
        onRetry: () {
          if (_query.isNotEmpty) {
            unawaited(
              _performSearch(
                _query,
              ),
            );
          }
        },
      );
    }

    if (_query.isEmpty) {
      return const _SearchInitialView();
    }

    if (_results.isEmpty) {
      return _NoResultsView(
        query: _query,
      );
    }

    return ListView.separated(
      physics:
          const BouncingScrollPhysics(),
      padding:
          EdgeInsets.fromLTRB(
        isTablet ? 32 : 16,
        isTablet ? 24 : 16,
        isTablet ? 32 : 16,
        32,
      ),
      itemCount:
          _results.length,
      separatorBuilder:
          (_, _) =>
              const SizedBox(
        height: 10,
      ),
      itemBuilder:
          (
        context,
        index,
      ) {
        final result =
            _results[index];

        final isLecture =
            result.type ==
                SearchResultType.lecture;

        return Card(
          elevation:
              0,
          child:
              InkWell(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            onTap:
                isLecture
                    ? () {
                        unawaited(
                          _openResult(
                            result,
                          ),
                        );
                      }
                    : null,
            child:
                Padding(
              padding:
                  EdgeInsets.all(
                isTablet
                    ? 18
                    : 14,
              ),
              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Container(
                    width:
                        isTablet
                            ? 54
                            : 48,
                    height:
                        isTablet
                            ? 54
                            : 48,
                    decoration:
                        BoxDecoration(
                      color: theme
                          .colorScheme
                          .primary
                          .withValues(
                        alpha:
                            0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child:
                        Icon(
                      _iconForType(
                        result.type,
                      ),
                      color: theme
                          .colorScheme
                          .primary,
                      size:
                          isTablet
                              ? 28
                              : 24,
                    ),
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  Text(
                                result.title,
                                maxLines:
                                    2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    TextStyle(
                                  fontSize:
                                      isTablet
                                          ? 17
                                          : 16,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ),

                            const SizedBox(
                              width:
                                  8,
                            ),

                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    8,
                                vertical:
                                    4,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: theme
                                    .colorScheme
                                    .primary
                                    .withValues(
                                  alpha:
                                      0.08,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child:
                                  Text(
                                _labelForType(
                                  result.type,
                                ),
                                style:
                                    TextStyle(
                                  fontSize:
                                      10,
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
                        ),

                        const SizedBox(
                          height:
                              6,
                        ),

                        Text(
                          _subtitleForResult(
                            result,
                          ),
                          maxLines:
                              2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              TextStyle(
                            color: theme
                                .colorScheme
                                .onSurface
                                .withValues(
                              alpha:
                                  0.60,
                            ),
                            fontSize:
                                13,
                          ),
                        ),

                        if (result
                                    .description !=
                                null &&
                            result.description!
                                .trim()
                                .isNotEmpty &&
                            result.type !=
                                SearchResultType.level) ...[
                          const SizedBox(
                            height:
                                5,
                          ),
                          Text(
                            result.description!
                                .trim(),
                            maxLines:
                                2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color:
                                  theme
                                      .colorScheme
                                      .onSurface
                                      .withValues(
                                alpha:
                                    0.50,
                              ),
                              fontSize:
                                  12,
                            ),
                          ),
                        ],

                        if (isLecture) ...[
                          const SizedBox(
                            height:
                                8,
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons
                                    .open_in_new_rounded,
                                size:
                                    15,
                                color:
                                    theme
                                        .colorScheme
                                        .primary,
                              ),
                              const SizedBox(
                                width:
                                    5,
                              ),
                              Text(
                                'Tap to open lecture',
                                style:
                                    TextStyle(
                                  fontSize:
                                      12,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color:
                                      theme
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

                  if (isLecture)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        top:
                            8,
                      ),
                      child:
                          Icon(
                        Icons
                            .chevron_right_rounded,
                        color:
                            theme
                                .colorScheme
                                .onSurface
                                .withValues(
                          alpha:
                              0.40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// INITIAL VIEW
// ============================================================================

class _SearchInitialView
    extends StatelessWidget {
  const _SearchInitialView();

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          32,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .search_rounded,
              size:
                  74,
              color: theme
                  .colorScheme
                  .primary
                  .withValues(
                alpha:
                    0.35,
              ),
            ),
            const SizedBox(
              height:
                  18,
            ),
            const Text(
              'Search MediData',
              style:
                  TextStyle(
                fontSize:
                    20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              'Find academic levels, modules and lectures.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color: theme
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
    );
  }
}

// ============================================================================
// NO RESULTS
// ============================================================================

class _NoResultsView
    extends StatelessWidget {
  final String query;

  const _NoResultsView({
    required this.query,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          32,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .search_off_rounded,
              size:
                  68,
              color:
                  theme
                      .colorScheme
                      .onSurface
                      .withValues(
                alpha:
                    0.30,
              ),
            ),
            const SizedBox(
              height:
                  16,
            ),
            Text(
              'No results found',
              style:
                  const TextStyle(
                fontSize:
                    19,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              'Nothing matched "$query".',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color: theme
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
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _ErrorState
    extends StatelessWidget {
  final String message;

  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          32,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .cloud_off_rounded,
              size:
                  60,
              color:
                  theme
                      .colorScheme
                      .error,
            ),
            const SizedBox(
              height:
                  16,
            ),
            const Text(
              'Search failed',
              style:
                  TextStyle(
                fontSize:
                    18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              message,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(
              height:
                  16,
            ),
            FilledButton.icon(
              onPressed:
                  onRetry,
              icon:
                  const Icon(
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