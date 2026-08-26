import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_brand.dart';
import '../../services/notification_service.dart';
import '../../services/student_profile_service.dart';
import '../../widgets/notification_bell.dart';
import 'ai_assistant_screen.dart';
import 'downloads_screen.dart';
import 'exam_history_screen.dart';
import 'exam_result_screen.dart';
import 'exam_review_screen.dart';
import 'exam_screen.dart';
import 'home_screen.dart';
import 'modules_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
  });

  @override
  State<AppShell> createState() =>
      _AppShellState();
}

class _AppShellState
    extends State<AppShell> {
  // ==========================================================================
  // SERVICES
  // ==========================================================================

  final SupabaseClient _supabase =
      Supabase.instance.client;

  final NotificationService
      _notificationService =
      NotificationService.instance;

  // ==========================================================================
  // MODULES SCREEN KEY
  // ==========================================================================

  final GlobalKey<ModulesScreenState>
      _modulesScreenKey =
      GlobalKey<ModulesScreenState>();

  // ==========================================================================
  // CURRENT PAGE
  // ==========================================================================

  int _currentIndex = 2;

  // ==========================================================================
  // APP PAGES
  // ==========================================================================

  late final List<Widget> _pages = [
    ModulesScreen(
      key:
          _modulesScreenKey,
    ),
    const AiAssistantScreen(),
    HomeScreen(
      onOpenLecture:
          _openLectureFromHome,
    ),
    const DownloadsScreen(),
    ProfileScreen(
      onOpenLecture:
          _openLectureFromHome,
      onExamAttemptTap:
          _openExamAttempt,
      onOpenExamHistory:
          _openExamHistory,
    ),
  ];

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _notificationService
        .setLectureTapHandler(
      _openLectureFromNotification,
    );

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) async {
        try {
          await _notificationService
              .initialize();
        } catch (e) {
          debugPrint(
            'AppShell notification initialization error: $e',
          );
        }

        if (!mounted) {
          return;
        }

        _openPendingNotificationLecture();
      },
    );
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _notificationService
        .clearLectureTapHandler();

    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      extendBody:
          true,
      body:
          SafeArea(
        top:
            true,
        bottom:
            false,
        child:
            Column(
          children: [
            const _AppHeader(),

            Expanded(
              child:
                  IndexedStack(
                index:
                    _currentIndex,
                children:
                    _pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          _CustomBottomNavigation(
        currentIndex:
            _currentIndex,
        onItemSelected:
            _onNavigationChanged,
      ),
    );
  }

  // ==========================================================================
  // PENDING NOTIFICATION
  // ==========================================================================

  void _openPendingNotificationLecture() {
    final lectureId =
        _notificationService
            .takePendingLectureId();

    if (lectureId == null ||
        lectureId.trim().isEmpty) {
      return;
    }

    _openLectureFromNotification(
      lectureId,
    );
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  void _onNavigationChanged(
    int index,
  ) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  // ==========================================================================
  // OPEN LECTURE FROM HOME
  // ==========================================================================

  void _openLectureFromHome({
    required String moduleId,
    required String moduleName,
    required String lectureId,
  }) {
    setState(() {
      _currentIndex = 0;
    });

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _modulesScreenKey
            .currentState
            ?.openLecture(
          moduleId:
              moduleId,
          lectureId:
              lectureId,
        );
      },
    );

    debugPrint(
      'OPEN LECTURE FROM HOME => '
      'moduleId=$moduleId, '
      'moduleName=$moduleName, '
      'lectureId=$lectureId',
    );
  }

  // ==========================================================================
  // OPEN LECTURE FROM NOTIFICATION / SEARCH
  // ==========================================================================

  Future<void>
      _openLectureFromNotification(
    String lectureId,
  ) async {
    final normalizedLectureId =
        lectureId.trim();

    if (normalizedLectureId.isEmpty) {
      return;
    }

    try {
      final response =
          await _supabase
              .from('lectures')
              .select('''
                id,
                module_id,
                title
              ''')
              .eq(
                'id',
                normalizedLectureId,
              )
              .maybeSingle();

      if (!mounted) {
        return;
      }

      if (response == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'This lecture is no longer available.',
            ),
          ),
        );

        return;
      }

      final lecture =
          Map<String, dynamic>.from(
        response,
      );

      final moduleId =
          lecture['module_id']
              ?.toString();

      if (moduleId == null ||
          moduleId.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to find this lecture module.',
            ),
          ),
        );

        return;
      }

      setState(() {
        _currentIndex = 0;
      });

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          _modulesScreenKey
              .currentState
              ?.openLecture(
            moduleId:
                moduleId,
            lectureId:
                normalizedLectureId,
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Open lecture error: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open this lecture.',
          ),
        ),
      );
    }
  }

  // ==========================================================================
  // OPEN EXAM HISTORY
  // ==========================================================================

  void _openExamHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ExamHistoryScreen(
          onAttemptTap:
              _openExamAttempt,
        ),
      ),
    );
  }

  // ==========================================================================
  // OPEN EXAM ATTEMPT
  // ==========================================================================

  Future<void> _openExamAttempt(
    StudentExamAttempt attempt,
  ) async {
    if (!mounted) {
      return;
    }

    try {
      final response =
          await _supabase
              .from('exams')
              .select('''
                id,
                title,
                duration_minutes,
                passing_score
              ''')
              .eq(
                'id',
                attempt.examId,
              )
              .maybeSingle();

      if (!mounted) {
        return;
      }

      if (response == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Exam information is no longer available.',
            ),
          ),
        );

        return;
      }

      final exam =
          Map<String, dynamic>.from(
        response,
      );

      final examId =
          exam['id']?.toString() ??
              attempt.examId;

      final examTitle =
          exam['title']?.toString() ??
              attempt.examTitle;

      final durationMinutes =
          (exam['duration_minutes']
                      as num?)
                  ?.toInt() ??
              0;

      final passingScore =
          (exam['passing_score']
                      as num?)
                  ?.toInt() ??
              attempt.passingScore;

      // ======================================================================
      // IN PROGRESS
      // ======================================================================

      if (attempt.isInProgress) {
        await Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder:
                (_) => ExamScreen(
              examId:
                  examId,
              attemptId:
                  attempt.id,
              examTitle:
                  examTitle,
              durationMinutes:
                  durationMinutes,
              passingScore:
                  passingScore,
            ),
          ),
        );

        return;
      }

      // ======================================================================
      // COMPLETED
      //
      // Open the result directly.
      // ======================================================================

      if (attempt.isCompleted) {
        await Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder:
                (_) => ExamResultScreen(
              examId:
                  examId,
              attemptId:
                  attempt.id,
              examTitle:
                  examTitle,
              durationMinutes:
                  durationMinutes,
              score:
                  attempt.score,
              correctAnswers:
                  attempt.correctAnswers,
              totalQuestions:
                  attempt.totalQuestions,
              passingScore:
                  passingScore,
              passed:
                  attempt.passed,
              autoSubmitted:
                  false,
            ),
          ),
        );

        return;
      }

      // ======================================================================
      // ABANDONED
      // ======================================================================

      await Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder:
              (_) => ExamReviewScreen(
            attemptId:
                attempt.id,
            examId:
                examId,
            examTitle:
                examTitle,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Open exam attempt error: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open this exam.',
          ),
        ),
      );
    }
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => SearchScreen(
          onOpenLecture:
              _openLectureFromNotification,
        ),
      ),
    );
  }
}

// ============================================================================
// APP HEADER
// ============================================================================

class _AppHeader
    extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final horizontalPadding =
        Responsive.horizontalPadding(
      context,
    );

    final width =
        Responsive.width(context);

    final headerHeight =
        Responsive.clamped(
      context,
      base:
          60,
      min:
          56,
      max:
          76,
    );

    final headerRadius =
        Responsive.clamped(
      context,
      base:
          20,
      min:
          16,
      max:
          28,
    );

    final logoSize =
        Responsive.clamped(
      context,
      base:
          58,
      min:
          50,
      max:
          70,
    );

    final iconSize =
        Responsive.iconSize(
      context,
      base:
          25,
      min:
          22,
      max:
          30,
    );

    final outerVerticalPadding =
        Responsive.spacing(
      context,
      base:
          8,
      min:
          6,
      max:
          14,
    );

    final bottomSpacing =
        Responsive.spacing(
      context,
      base:
          8,
      min:
          6,
      max:
          12,
    );

    return Padding(
      padding:
          EdgeInsets.fromLTRB(
        horizontalPadding,
        outerVerticalPadding,
        horizontalPadding,
        bottomSpacing,
      ),
      child:
          SizedBox(
        height:
            headerHeight,
        width:
            double.infinity,
        child:
            Stack(
          clipBehavior:
              Clip.none,
          alignment:
              Alignment.center,
          children: [
            // =================================================================
            // BACKGROUND
            // =================================================================

            Positioned.fill(
              child:
                  Container(
                decoration:
                    BoxDecoration(
                  color:
                      theme
                          .colorScheme
                          .surface,
                  borderRadius:
                      BorderRadius.circular(
                    headerRadius,
                  ),
                  border:
                      Border.all(
                    color:
                        isDark
                            ? Colors.white
                                .withValues(
                                alpha:
                                    0.06,
                              )
                            : Colors.black
                                .withValues(
                                alpha:
                                    0.04,
                              ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black
                              .withValues(
                        alpha:
                            isDark
                                ? 0.30
                                : 0.08,
                      ),
                      blurRadius:
                          Responsive.clamped(
                        context,
                        base:
                            18,
                        min:
                            14,
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
              ),
            ),

            // =================================================================
            // LOGO
            // =================================================================

            Container(
              width:
                  logoSize,
              height:
                  logoSize,
              padding:
                  EdgeInsets.all(
                Responsive.clamped(
                  context,
                  base:
                      5,
                  min:
                      4,
                  max:
                      7,
                ),
              ),
              decoration:
                  BoxDecoration(
                color:
                    theme
                        .colorScheme
                        .surface,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color:
                      isDark
                          ? Colors.white
                              .withValues(
                              alpha:
                                  0.08,
                            )
                          : Colors.black
                              .withValues(
                              alpha:
                                  0.04,
                            ),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black
                            .withValues(
                      alpha:
                          isDark
                              ? 0.22
                              : 0.08,
                    ),
                    blurRadius:
                        Responsive.clamped(
                      context,
                      base:
                          10,
                      min:
                          8,
                      max:
                          14,
                    ),
                    offset:
                        Responsive.clampedOffset(
                      context,
                      base:
                          const Offset(
                        0,
                        3,
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
                  ClipOval(
                child:
                    Image.asset(
                  AppBrand.logoPath,
                  fit:
                      BoxFit.contain,
                  errorBuilder:
                      (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Icon(
                      Icons
                          .medical_services_rounded,
                      color:
                          theme
                              .colorScheme
                              .primary,
                      size:
                          logoSize *
                              0.50,
                    );
                  },
                ),
              ),
            ),

            // =================================================================
            // SEARCH
            // =================================================================

            Positioned(
              left:
                  Responsive.spacing(
                context,
                base:
                    4,
                min:
                    2,
                max:
                    10,
              ),
              child:
                  _HeaderActionButton(
                tooltip:
                    'Search',
                icon:
                    Icons.search_rounded,
                iconSize:
                    iconSize,
                onTap:
                    () {
                  final state =
                      context
                          .findAncestorStateOfType<
                              _AppShellState>();

                  state?._openSearch();
                },
              ),
            ),

            // =================================================================
            // NOTIFICATIONS
            // =================================================================

            Positioned(
              right:
                  Responsive.spacing(
                context,
                base:
                    4,
                min:
                    2,
                max:
                    10,
              ),
              child:
                  NotificationBell(
                onLectureTap:
                    (
                  lectureId,
                ) async {
                  final state =
                      context
                          .findAncestorStateOfType<
                              _AppShellState>();

                  if (state != null) {
                    await state
                        ._openLectureFromNotification(
                      lectureId,
                    );
                  }
                },
              ),
            ),

            // =================================================================
            // EDGE PROTECTION
            // =================================================================

            if (width < 340)
              Positioned(
                left:
                    0,
                right:
                    0,
                child:
                    IgnorePointer(
                  child:
                      Container(
                    height:
                        1,
                    color:
                        Colors.transparent,
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
// HEADER ACTION BUTTON
// ============================================================================

class _HeaderActionButton
    extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final padding =
        Responsive.spacing(
      context,
      base:
          8,
      min:
          6,
      max:
          12,
    );

    return Tooltip(
      message:
          tooltip,
      child:
          Material(
        color:
            Colors.transparent,
        shape:
            const CircleBorder(),
        child:
            InkWell(
          onTap:
              onTap,
          customBorder:
              const CircleBorder(),
          child:
              Padding(
            padding:
                EdgeInsets.all(
              padding,
            ),
            child:
                Icon(
              icon,
              size:
                  iconSize,
              color:
                  theme
                      .colorScheme
                      .onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM BOTTOM NAVIGATION
// ============================================================================

class _CustomBottomNavigation
    extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>
      onItemSelected;

  const _CustomBottomNavigation({
    required this.currentIndex,
    required this.onItemSelected,
  });

  static const List<_NavItem>
      _items = [
    _NavItem(
      label:
          'Modules',
      icon:
          Icons.menu_book_outlined,
      selectedIcon:
          Icons.menu_book_rounded,
    ),
    _NavItem(
      label:
          'AI',
      icon:
          Icons.auto_awesome_outlined,
      selectedIcon:
          Icons.auto_awesome_rounded,
    ),
    _NavItem(
      label:
          'Home',
      icon:
          Icons.home_outlined,
      selectedIcon:
          Icons.home_rounded,
    ),
    _NavItem(
      label:
          'Downloads',
      icon:
          Icons.download_outlined,
      selectedIcon:
          Icons.download_rounded,
    ),
    _NavItem(
      label:
          'Profile',
      icon:
          Icons.person_outline,
      selectedIcon:
          Icons.person_rounded,
    ),
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final width =
        Responsive.width(context);

    final horizontalMargin =
        Responsive.clamped(
      context,
      base:
          12,
      min:
          6,
      max:
          48,
    );

    final bottomMargin =
        Responsive.clamped(
      context,
      base:
          10,
      min:
          6,
      max:
          22,
    );

    final navigationHeight =
        Responsive.clamped(
      context,
      base:
          74,
      min:
          68,
      max:
          88,
    );

    final borderRadius =
        Responsive.clamped(
      context,
      base:
          26,
      min:
          22,
      max:
          34,
    );

    final maxWidth =
        width >= 900
            ? 720.0
            : double.infinity;

    return SafeArea(
      top:
          false,
      child:
          Align(
        alignment:
            Alignment.bottomCenter,
        child:
            Container(
          constraints:
              BoxConstraints(
            maxWidth:
                maxWidth,
          ),
          margin:
              EdgeInsets.only(
            left:
                horizontalMargin,
            right:
                horizontalMargin,
            bottom:
                bottomMargin,
          ),
          height:
              navigationHeight,
          decoration:
              BoxDecoration(
            color:
                theme
                    .colorScheme
                    .surface,
            borderRadius:
                BorderRadius.circular(
              borderRadius,
            ),
            border:
                Border.all(
              color:
                  isDark
                      ? Colors.white
                          .withValues(
                          alpha:
                              0.05,
                        )
                      : Colors.black
                          .withValues(
                          alpha:
                              0.04,
                        ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black
                        .withValues(
                  alpha:
                      isDark
                          ? 0.30
                          : 0.14,
                ),
                blurRadius:
                    Responsive.clamped(
                  context,
                  base:
                      25,
                  min:
                      18,
                  max:
                      34,
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
              Row(
            children:
                List.generate(
              _items.length,
              (
                index,
              ) {
                return Expanded(
                  child:
                      _AnimatedNavItem(
                    item:
                        _items[index],
                    selected:
                        currentIndex ==
                            index,
                    onTap:
                        () =>
                            onItemSelected(
                      index,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED NAV ITEM
// ============================================================================

class _AnimatedNavItem
    extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final primaryColor =
        theme.colorScheme.primary;

    final isCompact =
        Responsive.width(context) <
            340;

    final selectedCircleSize =
        Responsive.clamped(
      context,
      base:
          58,
      min:
          52,
      max:
          68,
    );

    final iconSize =
        Responsive.clamped(
      context,
      base:
          25,
      min:
          22,
      max:
          30,
    );

    final normalIconSize =
        Responsive.clamped(
      context,
      base:
          23,
      min:
          20,
      max:
          28,
    );

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap:
          onTap,
      child:
          SizedBox(
        height:
            double.infinity,
        child:
            Stack(
          alignment:
              Alignment.center,
          clipBehavior:
              Clip.none,
          children: [
            // ================================================================
            // SELECTED CIRCLE
            // ================================================================

            AnimatedPositioned(
              duration:
                  const Duration(
                milliseconds:
                    350,
              ),
              curve:
                  Curves.easeOutBack,
              top:
                  selected
                      ? -Responsive.clamped(
                          context,
                          base:
                              20,
                          min:
                              16,
                          max:
                              24,
                        )
                      : Responsive.clamped(
                          context,
                          base:
                              15,
                          min:
                              12,
                          max:
                              20,
                        ),
              child:
                  AnimatedScale(
                duration:
                    const Duration(
                  milliseconds:
                      300,
                ),
                curve:
                    Curves.easeOutBack,
                scale:
                    selected
                        ? 1
                        : 0,
                child:
                    Container(
                  width:
                      selectedCircleSize,
                  height:
                      selectedCircleSize,
                  decoration:
                      BoxDecoration(
                    color:
                        primaryColor,
                    shape:
                        BoxShape.circle,
                    border:
                        isDark
                            ? Border.all(
                                color:
                                    Colors.white,
                                width:
                                    2,
                              )
                            : null,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black
                                .withValues(
                          alpha:
                              isDark
                                  ? 0.35
                                  : 0.10,
                        ),
                        blurRadius:
                            Responsive.clamped(
                          context,
                          base:
                              12,
                          min:
                              8,
                          max:
                              16,
                        ),
                        offset:
                            Responsive.clampedOffset(
                          context,
                          base:
                              const Offset(
                            0,
                            4,
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
                      Center(
                    child:
                        Icon(
                      item
                          .selectedIcon,
                      color:
                          Colors.white,
                      size:
                          iconSize,
                    ),
                  ),
                ),
              ),
            ),

            // ================================================================
            // NORMAL ITEM
            // ================================================================

            AnimatedPadding(
              duration:
                  const Duration(
                milliseconds:
                    300,
              ),
              curve:
                  Curves.easeOut,
              padding:
                  EdgeInsets.only(
                top:
                    selected
                        ? Responsive.clamped(
                            context,
                            base:
                                17,
                            min:
                                14,
                            max:
                                22,
                          )
                        : Responsive.clamped(
                            context,
                            base:
                                2,
                            min:
                                0,
                            max:
                                5,
                          ),
              ),
              child:
                  AnimatedOpacity(
                duration:
                    const Duration(
                  milliseconds:
                      220,
                ),
                opacity:
                    selected
                        ? 0
                        : 1,
                child:
                    Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Icon(
                      item.icon,
                      size:
                          normalIconSize,
                      color:
                          theme
                              .colorScheme
                              .onSurface
                              .withValues(
                        alpha:
                            0.50,
                      ),
                    ),
                    SizedBox(
                      height:
                          isCompact
                              ? 2
                              : 4,
                    ),
                    if (!isCompact)
                      Text(
                        item.label,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            TextStyle(
                          fontSize:
                              Responsive.clamped(
                            context,
                            base:
                                11,
                            min:
                                9,
                            max:
                                14,
                          ),
                          fontWeight:
                              FontWeight
                                  .w500,
                          color:
                              theme
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                            alpha:
                                0.50,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ================================================================
            // SELECTED LABEL
            // ================================================================

            AnimatedPositioned(
              duration:
                  const Duration(
                milliseconds:
                    300,
              ),
              curve:
                  Curves.easeOut,
              bottom:
                  selected
                      ? Responsive.clamped(
                          context,
                          base:
                              8,
                          min:
                              5,
                          max:
                              12,
                        )
                      : -10,
              child:
                  AnimatedOpacity(
                duration:
                    const Duration(
                  milliseconds:
                      220,
                ),
                opacity:
                    selected
                        ? 1
                        : 0,
                child:
                    Text(
                  item.label,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    fontSize:
                        Responsive.clamped(
                      context,
                      base:
                          11,
                      min:
                          9,
                      max:
                          14,
                    ),
                    fontWeight:
                        FontWeight.w600,
                    color:
                        primaryColor,
                  ),
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
// NAV ITEM
// ============================================================================

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
