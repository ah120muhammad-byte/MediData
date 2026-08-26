import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  final void Function({
    required String moduleId,
    required String moduleName,
    required String lectureId,
  }) onOpenLecture;

  const HomeScreen({
    super.key,
    required this.onOpenLecture,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  late Future<_HomeData> _homeFuture;

  @override
  void initState() {
    super.initState();

    _homeFuture =
        _loadHomeData();
  }

  // ===========================================================================
  // LOAD HOME
  // ===========================================================================

  Future<_HomeData> _loadHomeData() async {
    final user =
        _supabase.auth.currentUser;

    // =========================================================================
    // LATEST LECTURE
    // =========================================================================

    _LectureHomeData? latestLecture;

    final latestResponse =
        await _supabase
            .from('lectures')
            .select(
              '''
              id,
              module_id,
              title,
              description,
              published_at,
              is_published,
              is_active,
              modules (
                id,
                name
              )
              ''',
            )
            .eq(
              'is_active',
              true,
            )
            .eq(
              'is_published',
              true,
            )
            .order(
              'published_at',
              ascending:
                  false,
            )
            .limit(1);

    final latestRows =
        List<Map<String, dynamic>>.from(
      (latestResponse as List).map(
        (item) =>
            Map<String, dynamic>.from(
          item,
        ),
      ),
    );

    if (latestRows.isNotEmpty) {
      final row =
          latestRows.first;

      final moduleRaw =
          row['modules'];

      latestLecture =
          _LectureHomeData(
        id:
            row['id']?.toString() ??
                '',
        moduleId:
            row['module_id']
                    ?.toString() ??
                '',
        title:
            row['title']?.toString() ??
                '',
        description:
            row['description']
                ?.toString(),
        moduleName:
            moduleRaw is Map
                ? moduleRaw['name']
                        ?.toString() ??
                    'Module'
                : 'Module',
        publishedAt:
            DateTime.tryParse(
          row['published_at']
                  ?.toString() ??
              '',
        ),
      );
    }

    // =========================================================================
    // CURRENT MODULE
    // =========================================================================

    _ModuleHomeData? currentModule;

    if (user != null) {
      final latestProgressResponse =
          await _supabase
              .from(
                'lecture_progress',
              )
              .select(
                '''
                lecture_id,
                last_opened_at,
                lectures (
                  id,
                  module_id,
                  modules (
                    id,
                    name,
                    description
                  )
                )
                ''',
              )
              .eq(
                'user_id',
                user.id,
              )
              .order(
                'last_opened_at',
                ascending:
                    false,
              )
              .limit(1);

      final progressRows =
          List<Map<String, dynamic>>.from(
        (latestProgressResponse
                as List)
            .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        ),
      );

      if (progressRows.isNotEmpty) {
        final row =
            progressRows.first;

        final lectureRaw =
            row['lectures'];

        if (lectureRaw is Map) {
          final lecture =
              Map<String, dynamic>.from(
            lectureRaw,
          );

          final moduleRaw =
              lecture['modules'];

          if (moduleRaw is Map) {
            final module =
                Map<String, dynamic>.from(
              moduleRaw,
            );

            currentModule =
                _ModuleHomeData(
              id:
                  module['id']
                          ?.toString() ??
                      lecture['module_id']
                          ?.toString() ??
                      '',
              name:
                  module['name']
                          ?.toString() ??
                      'Current Module',
              description:
                  module['description']
                      ?.toString(),
            );
          }
        }
      }
    }

    // =========================================================================
    // MODULE PROGRESS
    // =========================================================================

    int totalTrackableLectures = 0;
    int completedLectures = 0;

    double moduleProgress = 0.0;

    if (currentModule != null &&
        user != null) {
      final lecturesResponse =
          await _supabase
              .from('lectures')
              .select(
                '''
                id,
                title
                ''',
              )
              .eq(
                'module_id',
                currentModule.id,
              )
              .eq(
                'is_active',
                true,
              )
              .eq(
                'is_published',
                true,
              )
              .order(
                'display_order',
                ascending:
                    true,
              );

      final lectures =
          List<Map<String, dynamic>>.from(
        (lecturesResponse as List).map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        ),
      );

      if (lectures.isNotEmpty) {
        final lectureIds =
            lectures
                .map(
                  (lecture) =>
                      lecture['id']
                          .toString(),
                )
                .toList();

        // ---------------------------------------------------------------------
        // LOAD ACTIVE MEDIA
        // ---------------------------------------------------------------------

        final filesResponse =
            await _supabase
                .from(
                  'lecture_files',
                )
                .select(
                  '''
                  id,
                  lecture_id,
                  file_type,
                  is_active
                  ''',
                )
                .inFilter(
                  'lecture_id',
                  lectureIds,
                )
                .eq(
                  'is_active',
                  true,
                );

        final files =
            List<Map<String, dynamic>>.from(
          (filesResponse as List).map(
            (item) =>
                Map<String, dynamic>.from(
              item,
            ),
          ),
        );

        // ---------------------------------------------------------------------
        // TRACKABLE LECTURES
        // ---------------------------------------------------------------------

        final trackableLectureIds =
            <String>{};

        for (final file
            in files) {
          final type =
              file['file_type']
                      ?.toString()
                      .toLowerCase()
                      .trim() ??
                  '';

          if (type == 'audio' ||
              type == 'video') {
            final lectureId =
                file['lecture_id']
                    ?.toString();

            if (lectureId != null &&
                lectureId.isNotEmpty) {
              trackableLectureIds.add(
                lectureId,
              );
            }
          }
        }

        totalTrackableLectures =
            trackableLectureIds.length;

        // ---------------------------------------------------------------------
        // LOAD PROGRESS
        // ---------------------------------------------------------------------

        if (trackableLectureIds
            .isNotEmpty) {
          final progressResponse =
              await _supabase
                  .from(
                    'lecture_progress',
                  )
                  .select(
                    '''
                    lecture_id,
                    audio_completed,
                    video_completed
                    ''',
                  )
                  .eq(
                    'user_id',
                    user.id,
                  )
                  .inFilter(
                    'lecture_id',
                    trackableLectureIds
                        .toList(),
                  );

          for (final item
              in (progressResponse
                  as List)) {
            final map =
                Map<String,
                    dynamic>.from(
              item,
            );

            final audioCompleted =
                map['audio_completed']
                        as bool? ??
                    false;

            final videoCompleted =
                map['video_completed']
                        as bool? ??
                    false;

            if (audioCompleted ||
                videoCompleted) {
              completedLectures++;
            }
          }

          if (completedLectures >
              totalTrackableLectures) {
            completedLectures =
                totalTrackableLectures;
          }
        }
      }

      if (totalTrackableLectures >
          0) {
        moduleProgress =
            completedLectures /
                totalTrackableLectures;
      }
    }

    return _HomeData(
      latestLecture:
          latestLecture,
      currentModule:
          currentModule,
      completedLectures:
          completedLectures,
      totalTrackableLectures:
          totalTrackableLectures,
      moduleProgress:
          moduleProgress,
    );
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _homeFuture =
          _loadHomeData();
    });

    await _homeFuture;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final contentMaxWidth =
            constraints.maxWidth >=
                    900
                ? 900.0
                : constraints.maxWidth;

        return Center(
          child:
              ConstrainedBox(
            constraints:
                BoxConstraints(
              maxWidth:
                  contentMaxWidth,
            ),
            child:
                FutureBuilder<
                    _HomeData>(
              future:
                  _homeFuture,
              builder:
                  (
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
                  debugPrint(
                    'Home error: ${snapshot.error}',
                  );

                  return _HomeErrorState(
                    onRetry:
                        _refresh,
                  );
                }

                final data =
                    snapshot.data ??
                        const _HomeData();

                final horizontalPadding =
                    Responsive.horizontalPadding(
                  context,
                );

                final topPadding =
                    Responsive.spacing(
                  context,
                  base:
                      24,
                  min:
                      16,
                  max:
                      36,
                );

                final bottomPadding =
                    Responsive.scrollBottomPadding(
                  context,
                  base:
                      115,
                );

                final sectionGap =
                    Responsive.spacing(
                  context,
                  base:
                      28,
                  min:
                      20,
                  max:
                      40,
                );

                final titleGap =
                    Responsive.spacing(
                  context,
                  base:
                      12,
                  min:
                      8,
                  max:
                      18,
                );

                return RefreshIndicator(
                  onRefresh:
                      _refresh,
                  child:
                      SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(
                      parent:
                          BouncingScrollPhysics(),
                    ),
                    padding:
                        EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        _SectionTitle(
                          title:
                              "What's New",
                        ),

                        SizedBox(
                          height:
                              titleGap,
                        ),

                        _LatestLectureCard(
                          lecture:
                              data.latestLecture,
                          onTap:
                              data.latestLecture ==
                                      null
                                  ? null
                                  : () {
                                      final lecture =
                                          data.latestLecture!;

                                      widget.onOpenLecture(
                                        moduleId:
                                            lecture.moduleId,
                                        moduleName:
                                            lecture.moduleName,
                                        lectureId:
                                            lecture.id,
                                      );
                                    },
                        ),

                        SizedBox(
                          height:
                              sectionGap,
                        ),

                        _SectionTitle(
                          title:
                              'Your Module',
                        ),

                        SizedBox(
                          height:
                              titleGap,
                        ),

                        _YourModuleCard(
                          module:
                              data.currentModule,
                          progress:
                              data.moduleProgress,
                          completedLectures:
                              data.completedLectures,
                          totalTrackableLectures:
                              data
                                  .totalTrackableLectures,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// HOME DATA
// ============================================================================

class _HomeData {
  final _LectureHomeData?
      latestLecture;

  final _ModuleHomeData?
      currentModule;

  final int completedLectures;
  final int totalTrackableLectures;

  final double moduleProgress;

  const _HomeData({
    this.latestLecture,
    this.currentModule,
    this.completedLectures =
        0,
    this.totalTrackableLectures =
        0,
    this.moduleProgress =
        0.0,
  });
}

// ============================================================================
// LECTURE MODEL
// ============================================================================

class _LectureHomeData {
  final String id;
  final String moduleId;

  final String title;
  final String? description;

  final String moduleName;
  final DateTime? publishedAt;

  const _LectureHomeData({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.moduleName,
    required this.publishedAt,
  });
}

// ============================================================================
// MODULE MODEL
// ============================================================================

class _ModuleHomeData {
  final String id;
  final String name;
  final String? description;

  const _ModuleHomeData({
    required this.id,
    required this.name,
    required this.description,
  });
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _SectionTitle
    extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Text(
      title,
      style:
          TextStyle(
        fontSize:
            Responsive.titleSize(
          context,
          base:
              22,
          min:
              19,
          max:
              30,
        ),
        fontWeight:
            FontWeight.bold,
        color:
            theme
                .colorScheme
                .onSurface,
      ),
    );
  }
}

// ============================================================================
// LATEST LECTURE CARD
// ============================================================================

class _LatestLectureCard
    extends StatelessWidget {
  final _LectureHomeData?
      lecture;

  final VoidCallback? onTap;

  const _LatestLectureCard({
    required this.lecture,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final cardRadius =
        Responsive.cardRadius(
      context,
    );

    final cardPadding =
        Responsive.cardPadding(
      context,
    );

    final iconContainer =
        Responsive.clamped(
      context,
      base:
          62,
      min:
          54,
      max:
          78,
    );

    final iconSize =
        Responsive.iconSize(
      context,
      base:
          29,
      min:
          25,
      max:
          38,
    );

    final gap =
        Responsive.spacing(
      context,
      base:
          14,
      min:
          10,
      max:
          20,
    );

    final titleSize =
        Responsive.titleSize(
      context,
      base:
          16,
          min:
              14,
          max:
              21,
    );

    if (lecture == null) {
      return _EmptyHomeCard(
        icon:
            Icons
                .play_lesson_outlined,
        title:
            'No New Lectures',
        message:
            'New published lectures will appear here.',
      );
    }

    return Material(
      color:
          theme
              .colorScheme
              .surface,
      borderRadius:
          BorderRadius.circular(
        cardRadius,
      ),
      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(
          cardRadius,
        ),
        onTap:
            onTap,
        child:
            Container(
          width:
              double.infinity,
          padding:
              EdgeInsets.all(
            cardPadding,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              cardRadius,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black
                        .withValues(
                  alpha:
                      theme.brightness ==
                              Brightness.dark
                          ? 0.20
                          : 0.07,
                ),
                blurRadius:
                    Responsive.clamped(
                  context,
                  base:
                      16,
                  min:
                      12,
                  max:
                      24,
                ),
                offset:
                    Responsive.clampedOffset(
                  context,
                  base:
                      const Offset(
                    0,
                    6,
                  ),
                  minScale:
                      0.8,
                  maxScale:
                      1.25,
                ),
              ),
            ],
          ),
          child:
              Row(
            children: [
              Container(
                width:
                    iconContainer,
                height:
                    iconContainer,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .primary
                          .withValues(
                    alpha:
                        0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    Responsive.smallRadius(
                      context,
                    ),
                  ),
                ),
                child:
                    Icon(
                  Icons
                      .play_lesson_outlined,
                  size:
                      iconSize,
                  color:
                      AppColors
                          .primary,
                ),
              ),

              SizedBox(
                width:
                    gap,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      lecture!
                          .moduleName,
                      maxLines:
                          1,
                      overflow:
                          TextOverflow
                              .ellipsis,
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
                        fontWeight:
                            FontWeight
                                .w600,
                        color:
                            AppColors
                                .primary,
                      ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      lecture!.title,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          TextStyle(
                        fontSize:
                            titleSize,
                        fontWeight:
                            FontWeight
                                .w700,
                        color:
                            theme
                                .colorScheme
                                .onSurface,
                      ),
                    ),

                    if (lecture!
                                .description !=
                            null &&
                        lecture!
                            .description!
                            .trim()
                            .isNotEmpty) ...[
                      SizedBox(
                        height:
                            Responsive.spacing(
                          context,
                          base:
                              5,
                          min:
                              4,
                          max:
                              8,
                        ),
                      ),
                      Text(
                        lecture!
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
                              Responsive.bodyTextSize(
                            context,
                            base:
                                12,
                            min:
                                11,
                            max:
                                15,
                          ),
                          height:
                              1.35,
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
                  ],
                ),
              ),

              SizedBox(
                width:
                    Responsive.spacing(
                  context,
                  base:
                      8,
                  min:
                      4,
                  max:
                      12,
                ),
              ),

              Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    theme
                        .colorScheme
                        .onSurface
                        .withValues(
                  alpha:
                      0.45,
                ),
                size:
                    Responsive.iconSize(
                  context,
                  base:
                      25,
                  min:
                      21,
                  max:
                      31,
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
// YOUR MODULE CARD
// ============================================================================

class _YourModuleCard
    extends StatelessWidget {
  final _ModuleHomeData?
      module;

  final double progress;

  final int completedLectures;
  final int totalTrackableLectures;

  const _YourModuleCard({
    required this.module,
    required this.progress,
    required this.completedLectures,
    required this.totalTrackableLectures,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (module == null) {
      return _EmptyHomeCard(
        icon:
            Icons
                .menu_book_rounded,
        title:
            'No Module Started',
        message:
            'Start studying a module and it will appear here.',
      );
    }

    final percentage =
        (progress * 100)
            .round()
            .clamp(
              0,
              100,
            );

    final cardPadding =
        Responsive.cardPadding(
      context,
    );

    final cardRadius =
        Responsive.cardRadius(
      context,
    );

    final avatarSize =
        Responsive.clamped(
      context,
      base:
          54,
      min:
          48,
      max:
          68,
    );

    final titleSize =
        Responsive.titleSize(
      context,
      base:
          19,
      min:
          17,
      max:
          25,
    );

    return Container(
      width:
          double.infinity,
      padding:
          EdgeInsets.all(
        cardPadding,
      ),
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary
                .withValues(
              alpha:
                  0.78,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          cardRadius,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppColors.primary
                    .withValues(
              alpha:
                  0.22,
            ),
            blurRadius:
                Responsive.clamped(
              context,
              base:
                  18,
              min:
                  14,
              max:
                  26,
            ),
            offset:
                Responsive.clampedOffset(
              context,
              base:
                  const Offset(
                0,
                8,
              ),
              minScale:
                  0.8,
              maxScale:
                  1.25,
            ),
          ),
        ],
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            children: [
              Container(
                width:
                    avatarSize,
                height:
                    avatarSize,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white
                          .withValues(
                    alpha:
                        0.18,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    Icon(
                  Icons
                      .menu_book_rounded,
                  color:
                      Colors.white,
                  size:
                      avatarSize *
                          0.48,
                ),
              ),

              SizedBox(
                width:
                    Responsive.spacing(
                  context,
                  base:
                      13,
                  min:
                      10,
                  max:
                      18,
                ),
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Current Module',
                      maxLines:
                          1,
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
                              11,
                          max:
                              15,
                        ),
                        color:
                            Colors.white
                                .withValues(
                          alpha:
                              0.78,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      module!.name,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          TextStyle(
                        fontSize:
                            titleSize,
                        fontWeight:
                            FontWeight
                                .bold,
                        color:
                            Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(
            height:
                Responsive.spacing(
              context,
              base:
                  20,
              min:
                  16,
              max:
                  28,
            ),
          ),

          Row(
            children: [
              Text(
                'Module Progress',
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
                  fontWeight:
                      FontWeight
                          .w600,
                  color: Colors.white
                      .withValues(
                    alpha:
                        0.80,
                  ),
                ),
              ),

              const Spacer(),

              Text(
                '$percentage%',
                style:
                    TextStyle(
                  fontSize:
                      Responsive.bodyTextSize(
                    context,
                    base:
                        14,
                    min:
                        13,
                    max:
                        18,
                  ),
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight
                          .w800,
                ),
              ),
            ],
          ),

          SizedBox(
            height:
                Responsive.spacing(
              context,
              base:
                  9,
              min:
                  7,
              max:
                  12,
            ),
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            child:
                LinearProgressIndicator(
              value:
                  progress.clamp(
                0.0,
                1.0,
              ),
              minHeight:
                  Responsive.clamped(
                context,
                base:
                    7,
                min:
                    6,
                max:
                    10,
              ),
              backgroundColor:
                  Colors.white
                      .withValues(
                alpha:
                    0.20,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                Colors.white,
              ),
            ),
          ),

          SizedBox(
            height:
                Responsive.spacing(
              context,
              base:
                  9,
              min:
                  7,
              max:
                  12,
            ),
          ),

          Text(
            totalTrackableLectures ==
                    0
                ? 'No audio or video content to track yet.'
                : '$completedLectures of $totalTrackableLectures lectures completed.',
            maxLines:
                2,
            overflow:
                TextOverflow.ellipsis,
            style:
                TextStyle(
              fontSize:
                  Responsive.smallTextSize(
                context,
                base:
                    11.5,
                min:
                    10.5,
                max:
                    14,
              ),
              height:
                  1.35,
              color:
                  Colors.white
                      .withValues(
                alpha:
                    0.75,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPTY HOME CARD
// ============================================================================

class _EmptyHomeCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyHomeCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final cardRadius =
        Responsive.cardRadius(
      context,
    );

    final cardPadding =
        Responsive.cardPadding(
      context,
    );

    final iconContainer =
        Responsive.clamped(
      context,
      base:
          56,
      min:
          50,
      max:
          72,
    );

    return Container(
      width:
          double.infinity,
      padding:
          EdgeInsets.all(
        cardPadding,
      ),
      decoration:
          BoxDecoration(
        color:
            theme
                .colorScheme
                .surface,
        borderRadius:
            BorderRadius.circular(
          cardRadius,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withValues(
              alpha:
                  theme.brightness ==
                          Brightness.dark
                      ? 0.18
                      : 0.06,
            ),
            blurRadius:
                Responsive.clamped(
              context,
              base:
                  16,
              min:
                  12,
              max:
                  24,
            ),
            offset:
                Responsive.clampedOffset(
              context,
              base:
                  const Offset(
                0,
                6,
              ),
              minScale:
                  0.8,
              maxScale:
                  1.25,
            ),
          ),
        ],
      ),
      child:
          Row(
        children: [
          Container(
            width:
                iconContainer,
            height:
                iconContainer,
            decoration:
                BoxDecoration(
              color:
                  AppColors.primary
                      .withValues(
                alpha:
                    0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                Responsive.smallRadius(
                  context,
                ),
              ),
            ),
            child:
                Icon(
              icon,
              size:
                  Responsive.iconSize(
                context,
                base:
                    26,
                min:
                    22,
                max:
                    34,
              ),
              color:
                  AppColors.primary,
            ),
          ),

          SizedBox(
            width:
                Responsive.spacing(
              context,
              base:
                  13,
              min:
                  10,
              max:
                  18,
            ),
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    fontSize:
                        Responsive.titleSize(
                      context,
                      base:
                          15,
                      min:
                          14,
                      max:
                          20,
                    ),
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                SizedBox(
                  height:
                      Responsive.spacing(
                    context,
                    base:
                        5,
                    min:
                        4,
                    max:
                        8,
                  ),
                ),

                Text(
                  message,
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
                          12,
                      min:
                          11,
                      max:
                          15,
                    ),
                    height:
                        1.35,
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
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _HomeErrorState
    extends StatelessWidget {
  final Future<void>
      Function()
      onRetry;

  const _HomeErrorState({
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
            EdgeInsets.all(
          Responsive.cardPadding(
            context,
          ),
        ),
        child:
            ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth:
                560,
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
                    Responsive.clamped(
                  context,
                  base:
                      60,
                  min:
                      50,
                  max:
                      76,
                ),
                color:
                    theme
                        .colorScheme
                        .error,
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
                'Unable to load your home data.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize:
                      Responsive.titleSize(
                    context,
                    base:
                        18,
                    min:
                        16,
                    max:
                        24,
                  ),
                  fontWeight:
                      FontWeight.w700,
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
                'Please check your connection and try again.',
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
                      theme
                          .colorScheme
                          .onSurface
                          .withValues(
                    alpha:
                        0.65,
                  ),
                ),
              ),

              SizedBox(
                height:
                    Responsive.spacing(
                  context,
                  base:
                      18,
                  min:
                      12,
                  max:
                      24,
                ),
              ),

              SizedBox(
                height:
                    Responsive.buttonHeight(
                  context,
                ),
                child:
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}