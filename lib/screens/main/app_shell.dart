import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_brand.dart';
import '../../services/notification_service.dart';
import '../../services/student_profile_service.dart';
import '../../widgets/notification_bell.dart';

import 'ai_assistant_screen.dart';
import 'downloads_screen.dart';
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
      key: _modulesScreenKey,
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
        await _notificationService
            .initialize();

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
    final size =
        MediaQuery.sizeOf(context);

    final isTablet =
        size.shortestSide >= 600;

    return Scaffold(
      extendBody: true,

      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // =================================================================
            // APP HEADER
            // =================================================================

            _AppHeader(
              isTablet: isTablet,
              onSearchPressed:
                  _openSearch,
              onLectureTap:
                  _openLectureFromNotification,
            ),

            // =================================================================
            // PAGE CONTENT
            // =================================================================

            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),

      // =======================================================================
      // BOTTOM NAVIGATION
      // =======================================================================

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
        lectureId.isEmpty) {
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
          moduleId: moduleId,
          lectureId: lectureId,
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
    if (lectureId.trim().isEmpty) {
      return;
    }

    try {
      // ----------------------------------------------------------------------
      // FIND MODULE
      // ----------------------------------------------------------------------

      final response =
          await _supabase
              .from('lectures')
              .select(
                '''
                id,
                module_id,
                title
                ''',
              )
              .eq(
                'id',
                lectureId,
              )
              .maybeSingle();

      if (!mounted) {
        return;
      }

      if (response == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to find this lecture module.',
            ),
          ),
        );

        return;
      }

      // ----------------------------------------------------------------------
      // OPEN MODULES TAB
      // ----------------------------------------------------------------------

      setState(() {
        _currentIndex = 0;
      });

      // ----------------------------------------------------------------------
      // OPEN LECTURE AFTER FRAME
      // ----------------------------------------------------------------------

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          _modulesScreenKey
              .currentState
              ?.openLecture(
            moduleId: moduleId,
            lectureId: lectureId,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open this lecture.',
          ),
        ),
      );
    }
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

    final response =
        await _supabase
            .from('exams')
            .select(
              '''
              id,
              title,
              duration_minutes,
              passing_score
              ''',
            )
            .eq(
              'id',
              attempt.examId,
            )
            .maybeSingle();

    if (!mounted) {
      return;
    }

    if (response == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
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
        exam['id'].toString();

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
            0;

    // =========================================================================
    // IN PROGRESS
    // =========================================================================

    if (attempt.isInProgress) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ExamScreen(
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

    // =========================================================================
    // COMPLETED
    // =========================================================================

    if (attempt.isCompleted) {
      _showCompletedAttemptActions(
        attempt: attempt,
        examId: examId,
        examTitle: examTitle,
        durationMinutes:
            durationMinutes,
        passingScore:
            passingScore,
      );

      return;
    }

    // =========================================================================
    // ABANDONED
    // =========================================================================

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ExamReviewScreen(
          attemptId:
              attempt.id,
          examId:
              examId,
          examTitle:
              examTitle,
        ),
      ),
    );
  }

  // ==========================================================================
  // COMPLETED EXAM ACTIONS
  // ==========================================================================

  void _showCompletedAttemptActions({
    required StudentExamAttempt attempt,
    required String examId,
    required String examTitle,
    required int durationMinutes,
    required int passingScore,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (
        sheetContext,
      ) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                // =============================================================
                // VIEW RESULT
                // =============================================================

                ListTile(
                  leading:
                      const CircleAvatar(
                    child: Icon(
                      Icons
                          .assessment_rounded,
                    ),
                  ),
                  title:
                      const Text(
                    'View Result',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle:
                      Text(
                    '${attempt.score}% • '
                    '${attempt.correctAnswers}/'
                    '${attempt.totalQuestions} correct',
                  ),
                  trailing:
                      const Icon(
                    Icons
                        .chevron_right_rounded,
                  ),
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    Navigator.of(
                      context,
                    ).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExamResultScreen(
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
                              attempt
                                  .correctAnswers,
                          totalQuestions:
                              attempt
                                  .totalQuestions,
                          passingScore:
                              passingScore,
                          passed:
                              attempt.passed,
                          autoSubmitted:
                              false,
                        ),
                      ),
                    );
                  },
                ),

                const Divider(
                  height: 1,
                ),

                // =============================================================
                // REVIEW ANSWERS
                // =============================================================

                ListTile(
                  leading:
                      const CircleAvatar(
                    child: Icon(
                      Icons
                          .rate_review_rounded,
                    ),
                  ),
                  title:
                      const Text(
                    'Review Answers',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle:
                      const Text(
                    'Review your answers, correct answers and explanations.',
                  ),
                  trailing:
                      const Icon(
                    Icons
                        .chevron_right_rounded,
                  ),
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    Navigator.of(
                      context,
                    ).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExamReviewScreen(
                          attemptId:
                              attempt.id,
                          examId:
                              examId,
                          examTitle:
                              examTitle,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SearchScreen(
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
  final bool isTablet;

  final VoidCallback
      onSearchPressed;

  final Future<void> Function(
    String lectureId,
  )? onLectureTap;

  const _AppHeader({
    required this.isTablet,
    required this.onSearchPressed,
    this.onLectureTap,
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

    final horizontalPadding =
        isTablet ? 32.0 : 18.0;

    final verticalPadding =
        isTablet ? 12.0 : 8.0;

    final headerHeight =
        isTablet ? 72.0 : 60.0;

    final logoSize =
        isTablet ? 68.0 : 58.0;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        isTablet ? 10.0 : 8.0,
      ),
      child: SizedBox(
        height: headerHeight,
        width: double.infinity,
        child: Stack(
          clipBehavior:
              Clip.none,
          alignment:
              Alignment.center,
          children: [
            // =================================================================
            // HEADER BACKGROUND
            // =================================================================

            Positioned.fill(
              child: Container(
                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme
                      .surface,
                  borderRadius:
                      BorderRadius.circular(
                    isTablet ? 24 : 20,
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white
                            .withValues(
                          alpha: 0.06,
                        )
                        : Colors.black
                            .withValues(
                          alpha: 0.04,
                        ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: isDark
                            ? 0.30
                            : 0.08,
                      ),
                      blurRadius: 18,
                      offset:
                          const Offset(
                        0,
                        6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =================================================================
            // CENTER LOGO
            // =================================================================

            Container(
              width: logoSize,
              height: logoSize,
              padding:
                  const EdgeInsets.all(
                5,
              ),
              decoration:
                  BoxDecoration(
                color: theme
                    .colorScheme
                    .surface,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color: isDark
                      ? Colors.white
                          .withValues(
                        alpha: 0.08,
                      )
                      : Colors.black
                          .withValues(
                        alpha: 0.04,
                      ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(
                      alpha: isDark
                          ? 0.22
                          : 0.08,
                    ),
                    blurRadius: 10,
                    offset:
                        const Offset(
                      0,
                      3,
                    ),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
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
                      color: theme
                          .colorScheme
                          .primary,
                      size: isTablet
                          ? 34
                          : 29,
                    );
                  },
                ),
              ),
            ),

            // =================================================================
            // LEFT — SEARCH
            // =================================================================

            Positioned(
              left:
                  isTablet ? 8 : 4,
              child: Material(
                color:
                    Colors.transparent,
                shape:
                    const CircleBorder(),
                child: InkWell(
                  onTap:
                      onSearchPressed,
                  customBorder:
                      const CircleBorder(),
                  child:
                      Padding(
                    padding:
                        EdgeInsets.all(
                      isTablet
                          ? 10
                          : 8,
                    ),
                    child:
                        Icon(
                      Icons
                          .search_rounded,
                      size: isTablet
                          ? 29
                          : 25,
                      color: theme
                          .colorScheme
                          .onSurface,
                    ),
                  ),
                ),
              ),
            ),

            // =================================================================
            // RIGHT — NOTIFICATIONS
            // =================================================================

            Positioned(
              right:
                  isTablet ? 8 : 4,
              child:
                  NotificationBell(
                onLectureTap:
                    onLectureTap,
              ),
            ),
          ],
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

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Modules',
      icon:
          Icons.menu_book_outlined,
      selectedIcon:
          Icons.menu_book_rounded,
    ),
    _NavItem(
      label: 'AI',
      icon:
          Icons.auto_awesome_outlined,
      selectedIcon:
          Icons.auto_awesome_rounded,
    ),
    _NavItem(
      label: 'Home',
      icon:
          Icons.home_outlined,
      selectedIcon:
          Icons.home_rounded,
    ),
    _NavItem(
      label: 'Downloads',
      icon:
          Icons.download_outlined,
      selectedIcon:
          Icons.download_rounded,
    ),
    _NavItem(
      label: 'Profile',
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
    final size =
        MediaQuery.sizeOf(context);

    final isTablet =
        size.shortestSide >= 600;

    final horizontalMargin =
        isTablet ? 40.0 : 12.0;

    final bottomMargin =
        isTablet ? 20.0 : 10.0;

    final maxWidth =
        isTablet
            ? 700.0
            : double.infinity;

    final theme =
        Theme.of(context);

    return SafeArea(
      top: false,
      child: Align(
        alignment:
            Alignment.bottomCenter,
        child: Container(
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
              isTablet ? 82 : 74,
          decoration:
              BoxDecoration(
            color: theme
                .colorScheme
                .surface,
            borderRadius:
                BorderRadius.circular(
              isTablet ? 30 : 26,
            ),
            border:
                Border.all(
              color: theme.brightness ==
                      Brightness.dark
                  ? Colors.white
                      .withValues(
                    alpha: 0.05,
                  )
                  : Colors.black
                      .withValues(
                    alpha: 0.04,
                  ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha:
                      theme.brightness ==
                              Brightness.dark
                          ? 0.30
                          : 0.14,
                ),
                blurRadius:
                    25,
                offset:
                    const Offset(
                  0,
                  8,
                ),
              ),
            ],
          ),
          child: Row(
            children:
                List.generate(
              _items.length,
              (index) =>
                  Expanded(
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
                  isTablet:
                      isTablet,
                ),
              ),
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
  final bool isTablet;

  const _AnimatedNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.isTablet,
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
        theme
            .colorScheme
            .primary;

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap:
          onTap,
      child: SizedBox(
        height:
            double.infinity,
        child: Stack(
          alignment:
              Alignment.center,
          clipBehavior:
              Clip.none,
          children: [
            // =================================================================
            // SELECTED CIRCLE
            // =================================================================

            AnimatedPositioned(
              duration:
                  const Duration(
                milliseconds: 350,
              ),
              curve:
                  Curves.easeOutBack,
              top:
                  selected
                      ? (isTablet
                          ? -22
                          : -20)
                      : (isTablet
                          ? 18
                          : 15),
              child:
                  AnimatedScale(
                duration:
                    const Duration(
                  milliseconds: 300,
                ),
                curve:
                    Curves.easeOutBack,
                scale:
                    selected
                        ? 1.0
                        : 0.0,
                child:
                    Container(
                  width:
                      isTablet
                          ? 62
                          : 58,
                  height:
                      isTablet
                          ? 62
                          : 58,
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
                                width: 2,
                              )
                            : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors
                            .black
                            .withValues(
                          alpha:
                              isDark
                                  ? 0.35
                                  : 0.10,
                        ),
                        blurRadius:
                            12,
                        offset:
                            const Offset(
                          0,
                          4,
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
                          isTablet
                              ? 27
                              : 25,
                    ),
                  ),
                ),
              ),
            ),

            // =================================================================
            // NORMAL ITEM
            // =================================================================

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
                        ? (isTablet
                            ? 18
                            : 17)
                        : (isTablet
                            ? 3
                            : 2),
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
                        ? 0.0
                        : 1.0,
                child:
                    Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Icon(
                      item.icon,
                      size:
                          isTablet
                              ? 25
                              : 23,
                      color: theme
                          .colorScheme
                          .onSurface
                          .withValues(
                        alpha:
                            0.50,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
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
                            isTablet
                                ? 13
                                : 11,
                        fontWeight:
                            FontWeight
                                .w500,
                        color: theme
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

            // =================================================================
            // SELECTED LABEL
            // =================================================================

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
                      ? (isTablet
                          ? 10
                          : 8)
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
                        ? 1.0
                        : 0.0,
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
                        isTablet
                            ? 13
                            : 11,
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