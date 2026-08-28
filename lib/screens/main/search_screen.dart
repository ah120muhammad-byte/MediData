import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../services/global_search_service.dart';

class SearchScreen extends StatefulWidget {
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
  // ===========================================================================
  // SERVICE
  // ===========================================================================

  final GlobalSearchService _searchService =
      GlobalSearchService.instance;

  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  final TextEditingController _controller =
      TextEditingController();

  final FocusNode _focusNode =
      FocusNode();

  // ===========================================================================
  // STATE
  // ===========================================================================

  Timer? _debounce;

  bool _loading = false;

  String _query = '';

  String? _error;

  List<GlobalSearchResult> _results =
      <GlobalSearchResult>[];

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        _focusNode.requestFocus();
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
  // SEARCH INPUT
  // ===========================================================================

  void _onSearchChanged(
    String value,
  ) {
    _debounce?.cancel();

    final query = value.trim();

    if (!mounted) {
      return;
    }

    setState(() {
      _query = query;
      _error = null;
    });

    if (query.isEmpty) {
      setState(() {
        _results = <GlobalSearchResult>[];
        _loading = false;
      });

      return;
    }

    _debounce = Timer(
      const Duration(
        milliseconds: 350,
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
    final normalizedQuery =
        query.trim();

    if (normalizedQuery.isEmpty ||
        !mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results =
          await _searchService.search(
        normalizedQuery,
      );

      if (!mounted) {
        return;
      }

      // Ignore stale responses when the user has
      // already typed a different query.
      if (_query != normalizedQuery) {
        return;
      }

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'Global search error: $e',
      );

      debugPrint(
        stackTrace.toString(),
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
  // SUBMIT
  // ===========================================================================

  void _submitSearch(
    String value,
  ) {
    final query = value.trim();

    if (query.isEmpty) {
      return;
    }

    _debounce?.cancel();

    _performSearch(query);
  }

  // ===========================================================================
  // CLEAR
  // ===========================================================================

  void _clearSearch() {
    _debounce?.cancel();

    _controller.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      _query = '';
      _results = <GlobalSearchResult>[];
      _loading = false;
      _error = null;
    });

    _focusNode.requestFocus();
  }

  // ===========================================================================
  // OPEN LECTURE
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

    final callback =
        widget.onOpenLecture;

    if (callback == null) {
      return;
    }

    _focusNode.unfocus();

    await callback(
      lectureId,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pop();
  }

  // ===========================================================================
  // TYPE ICON
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
  // TYPE LABEL
  // ===========================================================================

  String _labelForType(
    SearchResultType type,
  ) {
    switch (type) {
      case SearchResultType.level:
        return 'Level';

      case SearchResultType.module:
        return 'Module';

      case SearchResultType.lecture:
        return 'Lecture';
    }
  }

  // ===========================================================================
  // RESULT CONTEXT
  // ===========================================================================

  String _contextForResult(
    GlobalSearchResult result,
  ) {
    switch (result.type) {
      case SearchResultType.level:
        return 'Academic Level';

      case SearchResultType.module:
        if (result.levelName != null &&
            result.levelName!
                .trim()
                .isNotEmpty) {
          return result.levelName!
              .trim();
        }

        return 'Module';

      case SearchResultType.lecture:
        final parts =
            <String>[];

        if (result.levelName !=
                null &&
            result.levelName!
                .trim()
                .isNotEmpty) {
          parts.add(
            result.levelName!
                .trim(),
          );
        }

        if (result.moduleName !=
                null &&
            result.moduleName!
                .trim()
                .isNotEmpty) {
          parts.add(
            result.moduleName!
                .trim(),
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

    final colorScheme =
        theme.colorScheme;

    final width =
        Responsive.width(context);

    final isWide =
        width >= 700;

    return Scaffold(
      resizeToAvoidBottomInset:
          true,
      backgroundColor:
          colorScheme.surface,
      appBar:
          _buildAppBar(
        context,
        isWide,
      ),
      body:
          SafeArea(
        top: false,
        child:
            _buildBody(
          context,
          isWide,
        ),
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isWide,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return AppBar(
      elevation:
          0,
      backgroundColor:
          colorScheme.surface,
      surfaceTintColor:
          Colors.transparent,
      automaticallyImplyLeading:
          true,
      titleSpacing:
          isWide
              ? 12
              : 4,
      title:
          _buildSearchField(
        context,
      ),
    );
  }

  // ===========================================================================
  // SEARCH FIELD
  // ===========================================================================

  Widget _buildSearchField(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Container(
      height:
          Responsive.clamped(
        context,
        base: 46,
        min: 42,
        max: 52,
      ),
      decoration:
          BoxDecoration(
        color:
            colorScheme
                .surfaceContainerHighest
                .withValues(
              alpha:
                  .72,
            ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border:
            Border.all(
          color:
              colorScheme
                  .outline
                  .withValues(
            alpha:
                .10,
          ),
        ),
      ),
      child:
          TextField(
        controller:
            _controller,
        focusNode:
            _focusNode,
        autofocus:
            false,
        textInputAction:
            TextInputAction.search,
        textCapitalization:
            TextCapitalization.sentences,
        onChanged:
            _onSearchChanged,
        onSubmitted:
            _submitSearch,
        decoration:
            InputDecoration(
          border:
              InputBorder.none,
          hintText:
              'Search levels, modules or lectures...',
          hintStyle:
              TextStyle(
            fontSize:
                Responsive.bodyTextSize(
              context,
              base:
                  13,
              min:
                  12,
              max:
                  16,
            ),
            color:
                colorScheme
                    .onSurface
                    .withValues(
              alpha:
                  .45,
            ),
          ),
          prefixIcon:
              Icon(
            Icons
                .search_rounded,
            color:
                colorScheme
                    .onSurface
                    .withValues(
              alpha:
                  .55,
            ),
          ),
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
                            .close_rounded,
                      ),
                    ),
          contentPadding:
              const EdgeInsets
                  .symmetric(
            vertical:
                12,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BODY
  // ===========================================================================

  Widget _buildBody(
    BuildContext context,
    bool isWide,
  ) {
    if (_loading) {
      return _buildLoading(
        context,
      );
    }

    if (_error != null) {
      return _buildError(
        context,
      );
    }

    if (_query.isEmpty) {
      return const _SearchEmptyState();
    }

    if (_results.isEmpty) {
      return _SearchNoResultsState(
        query:
            _query,
      );
    }

    return Center(
      child:
          ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth:
              1100,
        ),
        child:
            ListView.separated(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
          physics:
              const BouncingScrollPhysics(),
          padding:
              EdgeInsets.fromLTRB(
            isWide
                ? 28
                : 16,
            isWide
                ? 24
                : 16,
            isWide
                ? 28
                : 16,
            Responsive.clamped(
              context,
              base:
                  22,
              min:
                  18,
              max:
                  30,
            ),
          ),
          itemCount:
              _results.length,
          separatorBuilder:
              (
            _,
            _,
          ) =>
              const SizedBox(
            height:
                10,
          ),
          itemBuilder:
              (
            context,
            index,
          ) {
            final result =
                _results[index];

            return _SearchResultCard(
              result:
                  result,
              icon:
                  _iconForType(
                result.type,
              ),
              typeLabel:
                  _labelForType(
                result.type,
              ),
              contextLabel:
                  _contextForResult(
                result,
              ),
              onTap:
                  result.type ==
                          SearchResultType
                              .lecture
                      ? () {
                          unawaited(
                            _openResult(
                              result,
                            ),
                          );
                        }
                      : null,
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoading(
    BuildContext context,
  ) {
    return Center(
      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const SizedBox(
            width:
                30,
            height:
                30,
            child:
                CircularProgressIndicator(
              strokeWidth:
                  2.6,
            ),
          ),
          const SizedBox(
            height:
                14,
          ),
          Text(
            'Searching...',
            style:
                TextStyle(
              fontSize:
                  Responsive.bodyTextSize(
                context,
                base:
                    13,
                min:
                    12,
                max:
                    16,
              ),
              color:
                  Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(
                alpha:
                    .55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildError(
    BuildContext context,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          24,
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
                  58,
              color:
                  Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(
                alpha:
                    .28,
              ),
            ),
            const SizedBox(
              height:
                  14,
            ),
            const Text(
              'Unable to search right now.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height:
                  14,
            ),
            FilledButton.icon(
              onPressed:
                  _query.isEmpty
                      ? null
                      : () {
                          unawaited(
                            _performSearch(
                              _query,
                            ),
                          );
                        },
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

// ============================================================================
// SEARCH RESULT CARD
// ============================================================================

class _SearchResultCard
    extends StatelessWidget {
  final GlobalSearchResult result;
  final IconData icon;
  final String typeLabel;
  final String contextLabel;
  final VoidCallback? onTap;

  const _SearchResultCard({
    required this.result,
    required this.icon,
    required this.typeLabel,
    required this.contextLabel,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    final bool isLecture =
        result.type ==
            SearchResultType.lecture;

    final double iconBoxSize =
        Responsive.clamped(
      context,
      base:
          48,
      min:
          44,
      max:
          56,
    );

    return Card(
      margin:
          EdgeInsets.zero,
      elevation:
          0,
      clipBehavior:
          Clip.antiAlias,
      child:
          InkWell(
        onTap:
            onTap,
        child:
            Padding(
          padding:
              EdgeInsets.all(
            Responsive.clamped(
              context,
              base:
                  13,
              min:
                  11,
              max:
                  18,
            ),
          ),
          child:
              Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Container(
                width:
                    iconBoxSize,
                height:
                    iconBoxSize,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .primary
                          .withValues(
                    alpha:
                        .10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  color:
                      AppColors
                          .primary,
                  size:
                      iconBoxSize *
                          .48,
                ),
              ),

              SizedBox(
                width:
                    Responsive.spacing(
                  context,
                  base:
                      12,
                  min:
                      9,
                  max:
                      16,
                ),
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
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
                                  Responsive.bodyTextSize(
                                context,
                                base:
                                    16,
                                min:
                                    14,
                                max:
                                    19,
                              ),
                              fontWeight:
                                  FontWeight
                                      .w700,
                              height:
                                  1.2,
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
                            color:
                                colorScheme
                                    .primary
                                    .withValues(
                              alpha:
                                  .08,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                          ),
                          child:
                              Text(
                            typeLabel,
                            style:
                                TextStyle(
                              fontSize:
                                  9.5,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color:
                                  colorScheme
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
                      contextLabel,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          TextStyle(
                        fontSize:
                            Responsive.smallTextSize(
                          context,
                          base:
                              12,
                          min:
                              10.5,
                          max:
                              14,
                        ),
                        color:
                            colorScheme
                                .onSurface
                                .withValues(
                          alpha:
                              .58,
                        ),
                      ),
                    ),

                    if (result.description !=
                            null &&
                        result.description!
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(
                        height:
                            5,
                      ),
                      Text(
                        result
                            .description!
                            .trim(),
                        maxLines:
                            2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            TextStyle(
                          fontSize:
                              Responsive.smallTextSize(
                            context,
                            base:
                                11.5,
                            min:
                                10,
                            max:
                                13.5,
                          ),
                          height:
                              1.3,
                          color:
                              colorScheme
                                  .onSurface
                                  .withValues(
                            alpha:
                                .46,
                          ),
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
                                .play_circle_outline_rounded,
                            size:
                                16,
                            color:
                                colorScheme
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
                                  11,
                              fontWeight:
                                  FontWeight
                                      .w600,
                              color:
                                  colorScheme
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
                    left:
                        4,
                    top:
                        8,
                  ),
                  child:
                      Icon(
                    Icons
                        .chevron_right_rounded,
                    color:
                        colorScheme
                            .onSurface
                            .withValues(
                      alpha:
                          .35,
                    ),
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
// INITIAL SEARCH VIEW
// ============================================================================

class _SearchEmptyState
    extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets
                .all(
          28,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width:
                  82,
              height:
                  82,
              decoration:
                  BoxDecoration(
                color:
                    colorScheme
                        .primary
                        .withValues(
                  alpha:
                      .08,
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  Icon(
                Icons
                    .search_rounded,
                size:
                    42,
                color:
                    colorScheme
                        .primary
                        .withValues(
                  alpha:
                      .65,
                ),
              ),
            ),
            const SizedBox(
              height:
                  18,
            ),
            Text(
              'Search MediData',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    Responsive.titleSize(
                  context,
                  base:
                      21,
                  min:
                      18,
                  max:
                      27,
                ),
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              'Find academic levels, modules and lectures quickly.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    Responsive.bodyTextSize(
                  context,
                  base:
                      13,
                  min:
                      12,
                  max:
                      16,
                ),
                color:
                    colorScheme
                        .onSurface
                        .withValues(
                  alpha:
                      .55,
                ),
                height:
                    1.45,
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

class _SearchNoResultsState
    extends StatelessWidget {
  final String query;

  const _SearchNoResultsState({
    required this.query,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          28,
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
                  60,
              color:
                  colorScheme
                      .onSurface
                      .withValues(
                alpha:
                    .25,
              ),
            ),
            const SizedBox(
              height:
                  14,
            ),
            const Text(
              'No results found',
              style:
                  TextStyle(
                fontSize:
                    19,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height:
                  7,
            ),
            Text(
              'Nothing matched “$query”.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    colorScheme
                        .onSurface
                        .withValues(
                  alpha:
                      .55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
