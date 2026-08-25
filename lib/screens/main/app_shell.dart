import 'package:flutter/material.dart';
import '../../services/student_profile_service.dart';
import '../../core/theme/app_brand.dart';
import '../main/ai_assistant_screen.dart';
import '../main/downloads_screen.dart';
import '../main/home_screen.dart';
import '../main/modules_screen.dart';
import '../main/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() =>
      _AppShellState();
}

class _AppShellState
    extends State<AppShell> {
  // ==========================================================================
  // CURRENT PAGE
  // ==========================================================================

  int _currentIndex = 2;

  // ==========================================================================
  // APP PAGES
  // ==========================================================================

  late final List<Widget> _pages = [
    const ModulesScreen(),

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

      // ========================================================================
      // BODY
      // ========================================================================

      body: SafeArea(
        top: true,
        bottom: false,
        child:
            Column(
          children: [
            // ==================================================================
            // APP HEADER
            // ==================================================================

            _AppHeader(
              isTablet: isTablet,
              onSearchPressed:
                  _openSearch,
            ),

            // ==================================================================
            // PAGE CONTENT
            // ==================================================================

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

      // ========================================================================
      // BOTTOM NAVIGATION
      // ========================================================================

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
  // NAVIGATION
  // ==========================================================================

  void _onNavigationChanged(
    int index,
  ) {
    if (_currentIndex ==
        index) {
      return;
    }

    setState(() {
      _currentIndex =
          index;
    });
  }

  // ==========================================================================
  // OPEN LECTURE
  //
  // Used by HomeScreen and ProfileScreen.
  //
  // We keep the navigation entry point here so both screens use
  // exactly the same behavior.
  // ==========================================================================

  void _openLectureFromHome({
    required String moduleId,
    required String moduleName,
    required String lectureId,
  }) {
    // ------------------------------------------------------------------------
    // For now we return to the Modules tab.
    //
    // The direct lecture navigation will be connected here to the current
    // LecturesScreen constructor once that constructor is unified with the
    // latest lecture-opening flow.
    // ------------------------------------------------------------------------

    setState(() {
      _currentIndex = 0;
    });

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Opening $moduleName...',
          ),
          duration:
              const Duration(
            milliseconds: 900,
          ),
        ),
      );

    debugPrint(
      'OPEN LECTURE => '
      'moduleId=$moduleId, '
      'moduleName=$moduleName, '
      'lectureId=$lectureId',
    );
  }

  // ==========================================================================
  // EXAM HISTORY
  //
  // We only select the exact saved attempt here.
  // The Resume / Review route will be connected to the current ExamScreen
  // after its attemptId constructor is unified.
  // ==========================================================================

  void _openExamAttempt(
    StudentExamAttempt attempt,
  ) {
    debugPrint(
      'OPEN EXAM ATTEMPT => '
      'attemptId=${attempt.id}, '
      'examId=${attempt.examId}, '
      'status=${attempt.status}',
    );

    String message;

    if (attempt.isInProgress) {
      message =
          'Resume exam: ${attempt.examTitle}';
    } else if (attempt.isCompleted) {
      message =
          'View result: ${attempt.examTitle}';
    } else {
      message =
          'View attempt: ${attempt.examTitle}';
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
          duration:
              const Duration(
            milliseconds: 1200,
          ),
        ),
      );
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  void _openSearch() {
    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Search will be available soon.',
          ),
          duration:
              Duration(seconds: 1),
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

  const _AppHeader({
    required this.isTablet,
    required this.onSearchPressed,
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
        isTablet
            ? 10.0
            : 8.0,
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
            // APP BAR BACKGROUND
            // =================================================================

            Positioned.fill(
              child:
                  Container(
                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme
                      .surface,
                  borderRadius:
                      BorderRadius
                          .circular(
                    isTablet
                        ? 24
                        : 20,
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
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors
                          .black
                          .withValues(
                        alpha:
                            isDark
                                ? 0.30
                                : 0.08,
                      ),
                      blurRadius:
                          18,
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
              width:
                  logoSize,
              height:
                  logoSize,
              padding:
                  const EdgeInsets
                      .all(
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
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors
                        .black
                        .withValues(
                      alpha:
                          isDark
                              ? 0.22
                              : 0.08,
                    ),
                    blurRadius:
                        10,
                    offset:
                        const Offset(
                      0,
                      3,
                    ),
                  ),
                ],
              ),
              child:
                  ClipOval(
                child:
                    Image.asset(
                  AppBrand
                      .logoPath,
                  fit:
                      BoxFit
                          .contain,
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
                          isTablet
                              ? 34
                              : 29,
                    );
                  },
                ),
              ),
            ),

            // =================================================================
            // SEARCH
            // =================================================================

            Positioned(
              right:
                  isTablet
                      ? 10
                      : 6,
              child:
                  Material(
                color:
                    Colors
                        .transparent,
                shape:
                    const CircleBorder(),
                child:
                    InkWell(
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
                      size:
                          isTablet
                              ? 29
                              : 25,
                      color:
                          theme
                              .colorScheme
                              .onSurface,
                    ),
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

  static const List<
      _NavItem> _items = [
    _NavItem(
      label:
          'Modules',
      icon:
          Icons
              .menu_book_outlined,
      selectedIcon:
          Icons
              .menu_book_rounded,
    ),
    _NavItem(
      label:
          'AI',
      icon:
          Icons
              .auto_awesome_outlined,
      selectedIcon:
          Icons
              .auto_awesome_rounded,
    ),
    _NavItem(
      label:
          'Home',
      icon:
          Icons
              .home_outlined,
      selectedIcon:
          Icons
              .home_rounded,
    ),
    _NavItem(
      label:
          'Downloads',
      icon:
          Icons
              .download_outlined,
      selectedIcon:
          Icons
              .download_rounded,
    ),
    _NavItem(
      label:
          'Profile',
      icon:
          Icons
              .person_outline,
      selectedIcon:
          Icons
              .person_rounded,
    ),
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    final size =
        MediaQuery.sizeOf(
      context,
    );

    final isTablet =
        size.shortestSide >=
            600;

    final horizontalMargin =
        isTablet
            ? 40.0
            : 12.0;

    final bottomMargin =
        isTablet
            ? 20.0
            : 10.0;

    final maxWidth =
        isTablet
            ? 700.0
            : double.infinity;

    final theme =
        Theme.of(context);

    return SafeArea(
      top:
          false,
      child:
          Align(
        alignment:
            Alignment
                .bottomCenter,
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
              isTablet
                  ? 82
                  : 74,
          decoration:
              BoxDecoration(
            color: theme
                .colorScheme
                .surface,
            borderRadius:
                BorderRadius
                    .circular(
              isTablet
                  ? 30
                  : 26,
            ),
            border:
                Border.all(
              color:
                  theme
                          .brightness ==
                      Brightness.dark
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
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors
                    .black
                    .withValues(
                  alpha:
                      theme
                              .brightness ==
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
          child:
              Row(
            children:
                List.generate(
              _items.length,
              (index) {
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
                    isTablet:
                        isTablet,
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
          HitTestBehavior
              .opaque,
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
                  Curves
                      .easeOutBack,
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
                  milliseconds:
                      300,
                ),
                curve:
                    Curves
                        .easeOutBack,
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
                        BoxShape
                            .circle,
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
                      item
                          .icon,
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
                      height:
                          4,
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
                        FontWeight
                            .w600,
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
// NAV ITEM MODEL
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