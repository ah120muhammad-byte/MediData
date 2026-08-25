import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    _homeFuture = _loadHomeData();
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

    final latestResponse = await _supabase
        .from('lectures')
        .select('''
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
        ''')
        .eq('is_active', true)
        .eq('is_published', true)
        .order(
          'published_at',
          ascending: false,
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
            row['id']?.toString() ?? '',
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
    //
    // Determined from the student's
    // latest lecture activity.
    // =========================================================================

    _ModuleHomeData? currentModule;

    if (user != null) {
      final latestProgressResponse =
          await _supabase
              .from('lecture_progress')
              .select('''
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
              ''')
              .eq(
                'user_id',
                user.id,
              )
              .order(
                'last_opened_at',
                ascending: false,
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
              .select('''
                id,
                title
              ''')
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
                ascending: true,
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
        // LOAD ACTIVE MEDIA FOR THESE LECTURES
        // ---------------------------------------------------------------------

        final filesResponse =
            await _supabase
                .from('lecture_files')
                .select('''
                  id,
                  lecture_id,
                  file_type,
                  is_active
                ''')
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
        //
        // A lecture is trackable when it has
        // at least one audio or video file.
        // ---------------------------------------------------------------------

        final trackableLectureIds =
            <String>{};

        for (final file in files) {
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
                  .select('''
                    lecture_id,
                    audio_completed,
                    video_completed
                  ''')
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
                Map<String, dynamic>.from(
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

            // A lecture is considered
            // completed when at least
            // one available media track
            // has been completed.
            if (audioCompleted ||
                videoCompleted) {
              completedLectures++;
            }
          }

          // Protect against bad/duplicate
          // records.
          if (completedLectures >
              totalTrackableLectures) {
            completedLectures =
                totalTrackableLectures;
          }
        }
      }

      if (totalTrackableLectures > 0) {
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
    final size =
        MediaQuery.sizeOf(context);

    final isTablet =
        size.shortestSide >= 600;

    final horizontalPadding =
        isTablet ? 32.0 : 20.0;

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final contentWidth =
            isTablet
                ? 850.0
                : constraints.maxWidth;

        return Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(
              maxWidth:
                  contentWidth,
            ),
            child:
                FutureBuilder<_HomeData>(
              future:
                  _homeFuture,
              builder:
                  (
                context,
                snapshot,
              ) {
                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  debugPrint(
                    'Home error: '
                    '${snapshot.error}',
                  );

                  return _HomeErrorState(
                    onRetry:
                        _refresh,
                  );
                }

                final data =
                    snapshot.data ??
                        const _HomeData();

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
                      isTablet
                          ? 28
                          : 22,
                      horizontalPadding,
                      isTablet
                          ? 130
                          : 115,
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        // =====================================================
                        // WHAT'S NEW
                        // =====================================================

                        _SectionTitle(
                          title:
                              "What's New",
                          isTablet:
                              isTablet,
                        ),

                        SizedBox(
                          height:
                              isTablet
                                  ? 16
                                  : 12,
                        ),

                        _LatestLectureCard(
                          lecture:
                              data.latestLecture,
                          isTablet:
                              isTablet,
                          onTap:
                              data.latestLecture ==
                                      null
                                  ? null
                                  : () {
                                      final lecture =
                                          data.latestLecture!;

                                      widget
                                          .onOpenLecture(
                                        moduleId:
                                            lecture
                                                .moduleId,
                                        moduleName:
                                            lecture
                                                .moduleName,
                                        lectureId:
                                            lecture
                                                .id,
                                      );
                                    },
                        ),

                        SizedBox(
                          height:
                              isTablet
                                  ? 34
                                  : 28,
                        ),

                        // =====================================================
                        // YOUR MODULE
                        // =====================================================

                        _SectionTitle(
                          title:
                              'Your Module',
                          isTablet:
                              isTablet,
                        ),

                        SizedBox(
                          height:
                              isTablet
                                  ? 16
                                  : 12,
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
                          isTablet:
                              isTablet,
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
    this.completedLectures = 0,
    this.totalTrackableLectures = 0,
    this.moduleProgress = 0.0,
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
  final bool isTablet;

  const _SectionTitle({
    required this.title,
    required this.isTablet,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Text(
      title,
      style: TextStyle(
        fontSize:
            isTablet ? 25 : 21,
        fontWeight:
            FontWeight.bold,
        color:
            theme.colorScheme.onSurface,
      ),
    );
  }
}

// ============================================================================
// LATEST LECTURE
// ============================================================================

class _LatestLectureCard
    extends StatelessWidget {
  final _LectureHomeData?
      lecture;

  final bool isTablet;
  final VoidCallback? onTap;

  const _LatestLectureCard({
    required this.lecture,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    if (lecture == null) {
      return _EmptyHomeCard(
        icon:
            Icons.play_lesson_outlined,
        title:
            'No New Lectures',
        message:
            'New published lectures will appear here.',
        isTablet:
            isTablet,
      );
    }

    return Material(
      color:
          theme.colorScheme.surface,
      borderRadius:
          BorderRadius.circular(
        isTablet ? 24 : 20,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          isTablet ? 24 : 20,
        ),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding:
              EdgeInsets.all(
            isTablet ? 22 : 17,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              isTablet ? 24 : 20,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha:
                      theme.brightness ==
                              Brightness.dark
                          ? 0.20
                          : 0.07,
                ),
                blurRadius: 16,
                offset:
                    const Offset(
                  0,
                  6,
                ),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width:
                    isTablet
                        ? 72
                        : 58,
                height:
                    isTablet
                        ? 72
                        : 58,
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .primary
                      .withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    isTablet
                        ? 20
                        : 16,
                  ),
                ),
                child: Icon(
                  Icons
                      .play_lesson_outlined,
                  size:
                      isTablet
                          ? 34
                          : 28,
                  color:
                      AppColors.primary,
                ),
              ),

              SizedBox(
                width:
                    isTablet
                        ? 18
                        : 14,
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
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
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
                            AppColors
                                .primary,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      lecture!
                          .title,
                      maxLines: 2,
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
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        lecture!
                            .description!
                            .trim(),
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            TextStyle(
                          fontSize:
                              isTablet
                                  ? 13
                                  : 12,
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

              const SizedBox(
                width: 8,
              ),

              Icon(
                Icons
                    .chevron_right_rounded,
                color: theme
                    .colorScheme
                    .onSurface
                    .withValues(
                  alpha: 0.45,
                ),
                size:
                    isTablet ? 30 : 25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// YOUR MODULE
// ============================================================================

class _YourModuleCard
    extends StatelessWidget {
  final _ModuleHomeData?
      module;

  final double progress;

  final int completedLectures;
  final int totalTrackableLectures;

  final bool isTablet;

  const _YourModuleCard({
    required this.module,
    required this.progress,
    required this.completedLectures,
    required this.totalTrackableLectures,
    required this.isTablet,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (module == null) {
      return _EmptyHomeCard(
        icon:
            Icons.menu_book_rounded,
        title:
            'No Module Started',
        message:
            'Start studying a module and it will appear here.',
        isTablet:
            isTablet,
      );
    }

    final percentage =
        (progress * 100)
            .round()
            .clamp(0, 100);

    return Container(
      width:
          double.infinity,
      padding:
          EdgeInsets.all(
        isTablet ? 24 : 18,
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
              alpha: 0.78,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          isTablet ? 26 : 21,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppColors.primary
                    .withValues(
              alpha: 0.22,
            ),
            blurRadius:
                18,
            offset:
                const Offset(
              0,
              8,
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
                    isTablet
                        ? 58
                        : 50,
                height:
                    isTablet
                        ? 58
                        : 50,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.18,
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
                      isTablet
                          ? 30
                          : 26,
                ),
              ),

              SizedBox(
                width:
                    isTablet
                        ? 16
                        : 13,
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
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          TextStyle(
                        fontSize:
                            isTablet
                                ? 14
                                : 12,
                        color:
                            Colors.white
                                .withValues(
                          alpha:
                              0.78,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      module!.name,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          TextStyle(
                        fontSize:
                            isTablet
                                ? 21
                                : 18,
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
                isTablet ? 24 : 20,
          ),

          Row(
            children: [
              Text(
                'Module Progress',
                style:
                    TextStyle(
                  fontSize:
                      isTablet
                          ? 14
                          : 12,
                  fontWeight:
                      FontWeight.w600,
                  color: Colors
                      .white
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
                    const TextStyle(
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
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
                  isTablet
                      ? 8
                      : 7,
              backgroundColor:
                  Colors.white
                      .withValues(
                alpha: 0.20,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                Colors.white,
              ),
            ),
          ),

          const SizedBox(
            height: 9,
          ),

          Text(
            totalTrackableLectures ==
                    0
                ? 'No audio or video content to track yet.'
                : '$completedLectures of $totalTrackableLectures lectures completed.',
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style:
                TextStyle(
              fontSize:
                  isTablet
                      ? 13
                      : 11.5,
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
// EMPTY CARD
// ============================================================================

class _EmptyHomeCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool isTablet;

  const _EmptyHomeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.isTablet,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Container(
      width:
          double.infinity,
      padding:
          EdgeInsets.all(
        isTablet
            ? 24
            : 20,
      ),
      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(
          isTablet ? 24 : 20,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  theme.brightness ==
                          Brightness.dark
                      ? 0.18
                      : 0.06,
            ),
            blurRadius:
                16,
            offset:
                const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width:
                isTablet
                    ? 64
                    : 54,
            height:
                isTablet
                    ? 64
                    : 54,
            decoration:
                BoxDecoration(
              color:
                  AppColors.primary
                      .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              size:
                  isTablet
                      ? 30
                      : 26,
              color:
                  AppColors.primary,
            ),
          ),

          SizedBox(
            width:
                isTablet
                    ? 16
                    : 13,
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
                  style:
                      TextStyle(
                    fontSize:
                        isTablet
                            ? 17
                            : 15,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  message,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    fontSize:
                        isTablet
                            ? 13
                            : 12,
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
  final Future<void> Function()
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
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
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

            const Text(
              'Unable to load your home data.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Please check your connection and try again.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 18,
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