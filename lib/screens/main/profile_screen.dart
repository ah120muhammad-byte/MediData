import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/student_preferences_service.dart';
import '../../services/student_profile_service.dart';

class ProfileScreen extends StatefulWidget {
  final void Function({
    required String moduleId,
    required String moduleName,
    required String lectureId,
  })? onOpenLecture;

  final void Function(
    StudentExamAttempt attempt,
  )? onExamAttemptTap;

  const ProfileScreen({
    super.key,
    this.onOpenLecture,
    this.onExamAttemptTap,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final StudentProfileService _service =
      StudentProfileService.instance;

  late Future<_ProfilePageData> _future;

  @override
  void initState() {
    super.initState();

    _future = _loadData();
  }

  Future<_ProfilePageData> _loadData() async {
    final profile =
        await _service.getProfile();

    final analytics =
        await _service.getAnalytics();

    return _ProfilePageData(
      profile: profile,
      analytics: analytics,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });

    await _future;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final size =
        MediaQuery.sizeOf(context);

    final isTablet =
        size.shortestSide >= 600;

    return FutureBuilder<
        _ProfilePageData>(
      future: _future,
      builder: (
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
          return _ErrorView(
            onRetry:
                _refresh,
          );
        }

        final data =
            snapshot.data;

        if (data == null) {
          return _ErrorView(
            onRetry:
                _refresh,
          );
        }

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
              isTablet ? 32 : 18,
              isTablet ? 24 : 16,
              isTablet ? 32 : 18,
              125,
            ),
            child: Center(
              child:
                  ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1000,
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    _ProfileHeader(
                      profile:
                          data.profile,
                      onEdit: () {
                        _showEditProfile(
                          data.profile,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    _OverviewGrid(
                      analytics:
                          data.analytics,
                      isTablet:
                          isTablet,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _SectionCard(
                      title:
                          'Study Activity',
                      icon:
                          Icons.insights_rounded,
                      child:
                          _StudyActivityChart(
                        activity:
                            data
                                .analytics
                                .dailyActivity,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _SectionCard(
                      title:
                          'Exam Performance',
                      icon:
                          Icons
                              .analytics_rounded,
                      child:
                          _ExamChart(
                        attempts:
                            data
                                .analytics
                                .attempts,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _SectionCard(
                      title:
                          'Exam Attempts',
                      icon:
                          Icons
                              .history_rounded,
                      child:
                          _ExamAttemptsList(
                        attempts:
                            data
                                .analytics
                                .attempts,
                        onAttemptTap:
                            widget
                                .onExamAttemptTap,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _SectionCard(
                      title:
                          'Lecture Activity',
                      icon:
                          Icons
                              .menu_book_rounded,
                      child:
                          _LectureActivityList(
                        activities:
                            data
                                .analytics
                                .lectureActivities,
                        onOpenLecture:
                            widget
                                .onOpenLecture,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _SectionCard(
                      title:
                          'Settings',
                      icon:
                          Icons
                              .settings_rounded,
                      child:
                          const _StudentSettings(),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _AccountActions(
                      onPassword:
                          _showChangePassword,
                      onLogout:
                          _showLogoutDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // EDIT PROFILE
  // ===========================================================================

  Future<void> _showEditProfile(
    StudentProfile profile,
  ) async {
    final nameController =
        TextEditingController(
      text: profile.fullName,
    );

    final phoneController =
        TextEditingController(
      text: profile.phone ?? '',
    );

    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title:
                  const Text(
                'Edit Profile',
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Full Name',
                        prefixIcon:
                            Icon(
                          Icons
                              .person_outline_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextField(
                      controller:
                          phoneController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Phone',
                        prefixIcon:
                            Icon(
                          Icons
                              .phone_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextField(
                      readOnly:
                          true,
                      controller:
                          TextEditingController(
                        text:
                            profile.email,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Email',
                        prefixIcon:
                            Icon(
                          Icons
                              .email_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving
                          ? null
                          : () {
                              Navigator.of(
                                dialogContext,
                              ).pop();
                            },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton(
                  onPressed:
                      saving
                          ? null
                          : () async {
                              final name =
                                  nameController
                                      .text
                                      .trim();

                              if (name
                                  .isEmpty) {
                                return;
                              }

                              setDialogState(
                                () {
                                  saving =
                                      true;
                                },
                              );

                              try {
                                await _service
                                    .updateProfile(
                                  fullName:
                                      name,
                                  phone:
                                      phoneController
                                          .text,
                                );

                                if (!mounted) {
                                  return;
                                }

                                Navigator.of(
                                  dialogContext,
                                ).pop();

                                await _refresh();
                              } catch (_) {
                                if (!context
                                    .mounted) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    saving =
                                        false;
                                  },
                                );

                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Unable to update profile.',
                                    ),
                                  ),
                                );
                              }
                            },
                  child:
                      saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Text(
                              'Save',
                            ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
  }

  // ===========================================================================
  // PASSWORD
  // ===========================================================================

  Future<void>
      _showChangePassword() async {
    final passwordController =
        TextEditingController();

    final confirmController =
        TextEditingController();

    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title:
                  const Text(
                'Change Password',
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          passwordController,
                      obscureText:
                          true,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'New Password',
                        prefixIcon:
                            Icon(
                          Icons
                              .lock_outline_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextField(
                      controller:
                          confirmController,
                      obscureText:
                          true,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Confirm Password',
                        prefixIcon:
                            Icon(
                          Icons
                              .lock_outline_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving
                          ? null
                          : () {
                              Navigator.of(
                                dialogContext,
                              ).pop();
                            },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton(
                  onPressed:
                      saving
                          ? null
                          : () async {
                              if (passwordController
                                          .text
                                          .length <
                                      6 ||
                                  passwordController
                                          .text !=
                                      confirmController
                                          .text) {
                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Check your passwords.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(
                                () {
                                  saving =
                                      true;
                                },
                              );

                              try {
                                await _service
                                    .updatePassword(
                                  passwordController
                                      .text,
                                );

                                if (!mounted) {
                                  return;
                                }

                                Navigator.of(
                                  dialogContext,
                                ).pop();

                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Password updated successfully.',
                                    ),
                                  ),
                                );
                              } catch (_) {
                                if (!context
                                    .mounted) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    saving =
                                        false;
                                  },
                                );

                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Unable to change password.',
                                    ),
                                  ),
                                );
                              }
                            },
                  child:
                      saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Text(
                              'Update',
                            ),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    confirmController.dispose();
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  Future<void> _showLogoutDialog() async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title:
              const Text(
            'Sign Out?',
          ),
          content:
              const Text(
            'You will need to sign in again to access your account.',
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
                'Sign Out',
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    await _service.signOut();
  }
}

// ============================================================================
// PAGE DATA
// ============================================================================

class _ProfilePageData {
  final StudentProfile profile;
  final StudentProfileAnalytics analytics;

  const _ProfilePageData({
    required this.profile,
    required this.analytics,
  });
}

// ============================================================================
// PROFILE HEADER
// ============================================================================

class _ProfileHeader
    extends StatelessWidget {
  final StudentProfile profile;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(
          20,
        ),
        child: Row(
          children: [
            _Avatar(
              profile:
                  profile,
            ),
            const SizedBox(
              width: 16,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    profile.fullName,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    profile.email,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      color: theme
                          .colorScheme
                          .onSurface
                          .withValues(
                        alpha: .60,
                      ),
                    ),
                  ),
                  if (profile.phone !=
                          null &&
                      profile.phone!
                          .isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      profile.phone!,
                      style:
                          TextStyle(
                        fontSize: 12,
                        color: theme
                            .colorScheme
                            .onSurface
                            .withValues(
                          alpha: .50,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed:
                  onEdit,
              tooltip:
                  'Edit profile',
              icon:
                  const Icon(
                Icons
                    .edit_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// AVATAR
// ============================================================================

class _Avatar
    extends StatelessWidget {
  final StudentProfile profile;

  const _Avatar({
    required this.profile,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final url =
        profile.profileImageUrl
            ?.trim();

    if (url != null &&
        url.isNotEmpty) {
      return CircleAvatar(
        radius: 34,
        backgroundImage:
            NetworkImage(url),
      );
    }

    final name =
        profile.fullName.trim();

    final initial =
        name.isEmpty
            ? '?'
            : name[0]
                .toUpperCase();

    return CircleAvatar(
      radius: 34,
      backgroundColor:
          AppColors.primary
              .withValues(
        alpha: .12,
      ),
      child:
          Text(
        initial,
        style:
            TextStyle(
          fontSize: 25,
          fontWeight:
              FontWeight.w800,
          color:
              AppColors.primary,
        ),
      ),
    );
  }
}

// ============================================================================
// OVERVIEW
// ============================================================================

class _OverviewGrid
    extends StatelessWidget {
  final StudentProfileAnalytics analytics;
  final bool isTablet;

  const _OverviewGrid({
    required this.analytics,
    required this.isTablet,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final columns =
        isTablet ? 4 : 2;

    return GridView.count(
      crossAxisCount:
          columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      childAspectRatio:
          isTablet ? 1.9 : 1.55,
      children: [
        _StatCard(
          title:
              'Lectures Opened',
          value:
              analytics.lecturesOpened,
          icon:
              Icons.menu_book_rounded,
        ),
        _StatCard(
          title:
              'Audio Completed',
          value:
              analytics.audioCompleted,
          icon:
              Icons.audio_file_rounded,
        ),
        _StatCard(
          title:
              'Video Completed',
          value:
              analytics.videoCompleted,
          icon:
              Icons.video_file_rounded,
        ),
        _StatCard(
          title:
              'Exam Attempts',
          value:
              analytics.examAttempts,
          icon:
              Icons.quiz_rounded,
        ),
        _StatCard(
          title:
              'Average Score',
          value:
              '${analytics.averageScore.toStringAsFixed(0)}%',
          icon:
              Icons.analytics_rounded,
        ),
        _StatCard(
          title:
              'Best Score',
          value:
              '${analytics.bestScore.toStringAsFixed(0)}%',
          icon:
              Icons.emoji_events_rounded,
        ),
        _StatCard(
          title:
              'Passed Exams',
          value:
              analytics.passedExams,
          icon:
              Icons.check_circle_rounded,
        ),
        _StatCard(
          title:
              'Success Rate',
          value:
              '${analytics.successRate.toStringAsFixed(0)}%',
          icon:
              Icons.trending_up_rounded,
        ),
      ],
    );
  }
}

// ============================================================================
// STAT CARD
// ============================================================================

class _StatCard
    extends StatelessWidget {
  final String title;
  final dynamic value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child:
            Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration:
                  BoxDecoration(
                color: theme
                    .colorScheme
                    .primary
                    .withValues(
                  alpha: .10,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  13,
                ),
              ),
              child:
                  Icon(
                icon,
                color: theme
                    .colorScheme
                    .primary,
              ),
            ),
            const SizedBox(
              width: 11,
            ),
            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      fontSize: 11,
                      color: theme
                          .colorScheme
                          .onSurface
                          .withValues(
                        alpha: .55,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    value.toString(),
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION
// ============================================================================

class _SectionCard
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: theme
                      .colorScheme
                      .primary,
                ),
                const SizedBox(
                  width: 9,
                ),
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STUDY CHART
// ============================================================================

class _StudyActivityChart
    extends StatelessWidget {
  final List<DailyStudyActivity>
      activity;

  const _StudyActivityChart({
    required this.activity,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final spots =
        List.generate(
      activity.length,
      (index) {
        return FlSpot(
          index.toDouble(),
          activity[index]
              .lecturesOpened
              .toDouble(),
        );
      },
    );

    final maxY =
        activity
            .map(
              (item) =>
                  item.lecturesOpened,
            )
            .fold<int>(
              0,
              (a, b) =>
                  a > b ? a : b,
            );

    return SizedBox(
      height: 230,
      child:
          LineChart(
        LineChartData(
          minY: 0,
          maxY:
              (maxY <= 1
                      ? 2
                      : maxY + 1)
                  .toDouble(),
          gridData:
              const FlGridData(
            show: false,
          ),
          borderData:
              FlBorderData(
            show: false,
          ),
          titlesData:
              FlTitlesData(
            leftTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: false,
              ),
            ),
            rightTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: false,
              ),
            ),
            topTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: false,
              ),
            ),
            bottomTitles:
                AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget:
                    (
                  value,
                  meta,
                ) {
                  final index =
                      value.round();

                  if (index <
                          0 ||
                      index >=
                          activity.length) {
                    return const SizedBox
                        .shrink();
                  }

                  final day =
                      activity[index]
                          .day;

                  return Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 8,
                    ),
                    child:
                        Text(
                      '${day.day}/${day.month}',
                      style:
                          const TextStyle(
                        fontSize:
                            10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots:
                  spots,
              isCurved:
                  true,
              barWidth:
                  3,
              dotData:
                  const FlDotData(
                show:
                    true,
              ),
              belowBarData:
                  BarAreaData(
                show:
                    true,
                color: theme
                    .colorScheme
                    .primary
                    .withValues(
                  alpha:
                      .10,
                ),
              ),
              color: theme
                  .colorScheme
                  .primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXAM CHART
// ============================================================================

class _ExamChart
    extends StatelessWidget {
  final List<StudentExamAttempt>
      attempts;

  const _ExamChart({
    required this.attempts,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final completed =
        attempts
            .where(
              (item) =>
                  item.isCompleted,
            )
            .take(10)
            .toList()
            .reversed
            .toList();

    if (completed.isEmpty) {
      return const SizedBox(
        height: 180,
        child:
            Center(
          child:
              Text(
            'No completed exams yet.',
          ),
        ),
      );
    }

    final spots =
        List.generate(
      completed.length,
      (index) =>
          FlSpot(
        index.toDouble(),
        completed[index]
            .score
            .toDouble(),
      ),
    );

    return SizedBox(
      height: 230,
      child:
          LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData:
              const FlGridData(
            show: false,
          ),
          borderData:
              FlBorderData(
            show: false,
          ),
          titlesData:
              const FlTitlesData(
            leftTitles:
                AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles:
                    false,
              ),
            ),
            rightTitles:
                AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles:
                    false,
              ),
            ),
            topTitles:
                AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles:
                    false,
              ),
            ),
            bottomTitles:
                AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles:
                    false,
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots:
                  spots,
              isCurved:
                  true,
              color: theme
                  .colorScheme
                  .primary,
              barWidth:
                  3,
              dotData:
                  const FlDotData(
                show:
                    true,
              ),
              belowBarData:
                  BarAreaData(
                show:
                    true,
                color: theme
                    .colorScheme
                    .primary
                    .withValues(
                  alpha:
                      .10,
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
// EXAM ATTEMPTS
// ============================================================================

class _ExamAttemptsList
    extends StatelessWidget {
  final List<StudentExamAttempt>
      attempts;

  final void Function(
    StudentExamAttempt attempt,
  )? onAttemptTap;

  const _ExamAttemptsList({
    required this.attempts,
    required this.onAttemptTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (attempts.isEmpty) {
      return const Padding(
        padding:
            EdgeInsets.all(12),
        child:
            Text(
          'No exam attempts yet.',
        ),
      );
    }

    return Column(
      children: attempts
          .take(15)
          .map(
            (attempt) =>
                _ExamAttemptTile(
              attempt:
                  attempt,
              onTap:
                  onAttemptTap == null
                      ? null
                      : () {
                          onAttemptTap!(
                            attempt,
                          );
                        },
            ),
          )
          .toList(),
    );
  }
}

class _ExamAttemptTile
    extends StatelessWidget {
  final StudentExamAttempt
      attempt;

  final VoidCallback? onTap;

  const _ExamAttemptTile({
    required this.attempt,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    late final Color
        statusColor;

    late final String
        statusLabel;

    if (attempt.isCompleted) {
      statusColor =
          attempt.passed
              ? Colors.green
              : theme
                  .colorScheme
                  .error;

      statusLabel =
          attempt.passed
              ? 'Passed'
              : 'Failed';
    } else if (attempt
        .isInProgress) {
      statusColor =
          theme
              .colorScheme
              .primary;

      statusLabel =
          'In Progress';
    } else {
      statusColor =
          Colors.orange;

      statusLabel =
          'Abandoned';
    }

    return ListTile(
      contentPadding:
          const EdgeInsets
              .symmetric(
        horizontal: 4,
      ),
      leading:
          CircleAvatar(
        backgroundColor:
            statusColor
                .withValues(
          alpha: .10,
        ),
        child:
            Icon(
          attempt.isInProgress
              ? Icons
                  .play_arrow_rounded
              : attempt.passed
                  ? Icons
                      .check_rounded
                  : Icons
                      .close_rounded,
          color:
              statusColor,
        ),
      ),
      title:
          Text(
        attempt.examTitle,
        maxLines: 2,
        overflow:
            TextOverflow
                .ellipsis,
        style:
            const TextStyle(
          fontWeight:
              FontWeight.w700,
        ),
      ),
      subtitle:
          Text(
        attempt.isCompleted
            ? '${attempt.score}% • $statusLabel'
            : statusLabel,
      ),
      trailing:
          const Icon(
        Icons
            .chevron_right_rounded,
      ),
      onTap:
          onTap,
    );
  }
}

// ============================================================================
// LECTURE ACTIVITY
// ============================================================================

class _LectureActivityList
    extends StatelessWidget {
  final List<StudentLectureActivity>
      activities;

  final void Function({
    required String moduleId,
    required String moduleName,
    required String lectureId,
  })? onOpenLecture;

  const _LectureActivityList({
    required this.activities,
    required this.onOpenLecture,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (activities.isEmpty) {
      return const Padding(
        padding:
            EdgeInsets.all(12),
        child:
            Text(
          'No lecture activity yet.',
        ),
      );
    }

    return Column(
      children: activities
          .take(15)
          .map(
            (activity) =>
                ListTile(
              contentPadding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 4,
              ),
              leading:
                  CircleAvatar(
                backgroundColor:
                    AppColors
                        .primary
                        .withValues(
                  alpha:
                      .10,
                ),
                child:
                    const Icon(
                  Icons
                      .menu_book_rounded,
                ),
              ),
              title:
                  Text(
                activity
                    .lectureTitle,
                maxLines: 2,
                overflow:
                    TextOverflow
                        .ellipsis,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight
                          .w700,
                ),
              ),
              subtitle:
                  Text(
                '${activity.moduleName} • '
                '${activity.progressPercent}% progress',
              ),
              trailing:
                  const Icon(
                Icons
                    .chevron_right_rounded,
              ),
              onTap:
                  onOpenLecture ==
                          null
                      ? null
                      : () {
                          onOpenLecture!(
                            moduleId:
                                activity
                                    .moduleId,
                            moduleName:
                                activity
                                    .moduleName,
                            lectureId:
                                activity
                                    .lectureId,
                          );
                        },
            ),
          )
          .toList(),
    );
  }
}

// ============================================================================
// SETTINGS
// ============================================================================

class _StudentSettings
    extends StatefulWidget {
  const _StudentSettings();

  @override
  State<_StudentSettings>
      createState() =>
          _StudentSettingsState();
}

class _StudentSettingsState
    extends State<
        _StudentSettings> {
  final StudentPreferencesService
      _preferences =
      StudentPreferencesService
          .instance;

  bool _loading =
      true;

  bool _notifications =
      true;

  bool _autoPlay =
      true;

  bool _wifiOnlyDownloads =
      true;

  double _defaultSpeed =
      1.0;

  @override
  void initState() {
    super.initState();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final notifications =
          await _preferences
              .getNotificationsEnabled();

      final autoPlay =
          await _preferences
              .getAutoPlayEnabled();

      final wifiOnly =
          await _preferences
              .getWifiOnlyDownloads();

      final speed =
          await _preferences
              .getDefaultPlaybackSpeed();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications =
            notifications;
        _autoPlay =
            autoPlay;
        _wifiOnlyDownloads =
            wifiOnly;
        _defaultSpeed =
            speed;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Load student settings error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Padding(
        padding:
            EdgeInsets.all(20),
        child:
            Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        SwitchListTile(
          contentPadding:
              EdgeInsets.zero,
          title:
              const Text(
            'Notifications',
          ),
          subtitle:
              const Text(
            'Receive study and exam reminders.',
          ),
          value:
              _notifications,
          onChanged:
              (value) async {
            setState(() {
              _notifications =
                  value;
            });

            await _preferences
                .setNotificationsEnabled(
              value,
            );
          },
        ),

        SwitchListTile(
          contentPadding:
              EdgeInsets.zero,
          title:
              const Text(
            'Auto Play Media',
          ),
          subtitle:
              const Text(
            'Automatically start audio or video.',
          ),
          value:
              _autoPlay,
          onChanged:
              (value) async {
            setState(() {
              _autoPlay =
                  value;
            });

            await _preferences
                .setAutoPlayEnabled(
              value,
            );
          },
        ),

        SwitchListTile(
          contentPadding:
              EdgeInsets.zero,
          title:
              const Text(
            'Wi-Fi Only Downloads',
          ),
          subtitle:
              const Text(
            'Prevent lecture downloads over mobile data.',
          ),
          value:
              _wifiOnlyDownloads,
          onChanged:
              (value) async {
            setState(() {
              _wifiOnlyDownloads =
                  value;
            });

            await _preferences
                .setWifiOnlyDownloads(
              value,
            );
          },
        ),

        ListTile(
          contentPadding:
              EdgeInsets.zero,
          title:
              const Text(
            'Default Playback Speed',
          ),
          subtitle:
              const Text(
            'Used when opening audio lectures.',
          ),
          trailing:
              DropdownButton<double>(
            value:
                _defaultSpeed,
            items:
                const [
              DropdownMenuItem(
                value:
                    .75,
                child:
                    Text(
                  '0.75x',
                ),
              ),
              DropdownMenuItem(
                value:
                    1.0,
                child:
                    Text(
                  '1.0x',
                ),
              ),
              DropdownMenuItem(
                value:
                    1.25,
                child:
                    Text(
                  '1.25x',
                ),
              ),
              DropdownMenuItem(
                value:
                    1.5,
                child:
                    Text(
                  '1.5x',
                ),
              ),
              DropdownMenuItem(
                value:
                    1.75,
                child:
                    Text(
                  '1.75x',
                ),
              ),
              DropdownMenuItem(
                value:
                    2.0,
                child:
                    Text(
                  '2.0x',
                ),
              ),
            ],
            onChanged:
                (value) async {
              if (value ==
                  null) {
                return;
              }

              setState(() {
                _defaultSpeed =
                    value;
              });

              await _preferences
                  .setDefaultPlaybackSpeed(
                value,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ACCOUNT ACTIONS
// ============================================================================

class _AccountActions
    extends StatelessWidget {
  final VoidCallback onPassword;
  final VoidCallback onLogout;

  const _AccountActions({
    required this.onPassword,
    required this.onLogout,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation:
          0,
      child:
          Column(
        children: [
          ListTile(
            leading:
                const Icon(
              Icons
                  .lock_outline_rounded,
            ),
            title:
                const Text(
              'Change Password',
            ),
            trailing:
                const Icon(
              Icons
                  .chevron_right_rounded,
            ),
            onTap:
                onPassword,
          ),
          const Divider(
            height:
                1,
          ),
          ListTile(
            leading:
                Icon(
              Icons
                  .logout_rounded,
              color:
                  theme
                      .colorScheme
                      .error,
            ),
            title:
                Text(
              'Sign Out',
              style:
                  TextStyle(
                color:
                    theme
                        .colorScheme
                        .error,
                fontWeight:
                    FontWeight
                        .w700,
              ),
            ),
            onTap:
                onLogout,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _ErrorView
    extends StatelessWidget {
  final Future<void>
      Function() onRetry;

  const _ErrorView({
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          30,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .cloud_off_rounded,
              size:
                  60,
            ),
            const SizedBox(
              height:
                  16,
            ),
            const Text(
              'Unable to load profile data.',
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
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}