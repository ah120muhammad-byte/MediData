import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../services/student_preferences_service.dart';
import '../../services/student_profile_service.dart';

class ProfileScreen extends StatefulWidget {
  final void Function({
    required String moduleId,
    required String moduleName,
    required String lectureId,
  })?
  onOpenLecture;

  final void Function(StudentExamAttempt attempt)? onExamAttemptTap;
  final VoidCallback? onOpenExamHistory;
  const ProfileScreen({
    super.key,
    this.onOpenLecture,
    this.onExamAttemptTap,
    this.onOpenExamHistory,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StudentProfileService _service = StudentProfileService.instance;

  late Future<_ProfilePageData> _future;

  @override
  void initState() {
    super.initState();

    _future = _loadData();
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<_ProfilePageData> _loadData() async {
    final profile = await _service.getProfile();
    final analytics = await _service.getAnalytics();

    return _ProfilePageData(profile: profile, analytics: analytics);
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _future = _loadData();
    });

    await _future;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfilePageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorView(onRetry: _refresh);
        }

        final data = snapshot.data;

        if (data == null) {
          return _ErrorView(onRetry: _refresh);
        }

        final horizontalPadding = Responsive.horizontalPadding(context);

        final bottomPadding = Responsive.scrollBottomPadding(
          context,
          base: 125,
        );

        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              Responsive.spacing(context, base: 18, min: 12, max: 30),
              horizontalPadding,
              bottomPadding,
            ),
            child: Responsive.constrained(
              context,
              maxWidth: 1100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(
                    profile: data.profile,
                    onEdit: () => _showEditProfile(data.profile),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 18,
                      min: 14,
                      max: 28,
                    ),
                  ),

                  _OverviewGrid(analytics: data.analytics),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 20,
                      min: 16,
                      max: 30,
                    ),
                  ),

                  _SectionCard(
                    title: 'Study Activity',
                    icon: Icons.insights_rounded,
                    child: _StudyActivityChart(
                      activity: data.analytics.dailyActivity,
                    ),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 20,
                      min: 16,
                      max: 30,
                    ),
                  ),

                  _SectionCard(
                    title: 'Exam Performance',
                    icon: Icons.analytics_rounded,
                    child: _ExamChart(attempts: data.analytics.attempts),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 20,
                      min: 16,
                      max: 30,
                    ),
                  ),

                  _SectionCard(
                    title: 'Exam Attempts',
                    icon: Icons.history_rounded,
                    trailing: widget.onOpenExamHistory == null
                        ? null
                        : TextButton(
                            onPressed: widget.onOpenExamHistory,
                            child: const Text('View All'),
                          ),
                    child: _ExamAttemptsList(
                      attempts: data.analytics.attempts,
                      onAttemptTap: widget.onExamAttemptTap,
                    ),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 20,
                      min: 16,
                      max: 30,
                    ),
                  ),

                  _SectionCard(
                    title: 'Lecture Activity',
                    icon: Icons.menu_book_rounded,
                    child: _LectureActivityList(
                      activities: data.analytics.lectureActivities,
                      onOpenLecture: widget.onOpenLecture,
                    ),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 20,
                      min: 16,
                      max: 30,
                    ),
                  ),

                  _SectionCard(
                    title: 'Settings',
                    icon: Icons.settings_rounded,
                    child: const _StudentSettings(),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 20,
                      min: 16,
                      max: 30,
                    ),
                  ),

                  _AccountActions(
                    onPassword: _showChangePassword,
                    onLogout: _showLogoutDialog,
                  ),
                ],
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

  Future<void> _showEditProfile(StudentProfile profile) async {
    final nameController = TextEditingController(text: profile.fullName);

    final phoneController = TextEditingController(text: profile.phone ?? '');

    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    SizedBox(
                      height: Responsive.spacing(
                        dialogContext,
                        base: 14,
                        min: 10,
                        max: 18,
                      ),
                    ),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    SizedBox(
                      height: Responsive.spacing(
                        dialogContext,
                        base: 14,
                        min: 10,
                        max: 18,
                      ),
                    ),
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(text: profile.email),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();

                          if (name.isEmpty) {
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await _service.updateProfile(
                              fullName: name,
                              phone: phoneController.text,
                            );

                            if (!mounted) {
                              return;
                            }

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.of(dialogContext).pop();

                            await _refresh();
                          } catch (_) {
                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              saving = false;
                            });

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Unable to update profile.'),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
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

  Future<void> _showChangePassword() async {
    final passwordController = TextEditingController();

    final confirmController = TextEditingController();

    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    SizedBox(
                      height: Responsive.spacing(
                        dialogContext,
                        base: 14,
                        min: 10,
                        max: 18,
                      ),
                    ),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (passwordController.text.length < 6 ||
                              passwordController.text !=
                                  confirmController.text) {
                            if (!dialogContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Check your passwords.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await _service.updatePassword(
                              passwordController.text,
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.of(dialogContext).pop();

                            if (!mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully.'),
                              ),
                            );
                          } catch (_) {
                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              saving = false;
                            });

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Unable to change password.'),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update'),
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
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: const Text(
            'You will need to sign in again to access your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign Out'),
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

  const _ProfilePageData({required this.profile, required this.analytics});
}

// ============================================================================
// PROFILE HEADER
// ============================================================================

class _ProfileHeader extends StatelessWidget {
  final StudentProfile profile;
  final VoidCallback onEdit;

  const _ProfileHeader({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final padding = Responsive.cardPadding(context);

    final avatarRadius = Responsive.clamped(
      context,
      base: 34,
      min: 28,
      max: 46,
    );

    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(profile: profile, radius: avatarRadius),
            SizedBox(
              width: Responsive.spacing(context, base: 16, min: 12, max: 24),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.titleSize(
                        context,
                        base: 21,
                        min: 18,
                        max: 28,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 5,
                      min: 3,
                      max: 8,
                    ),
                  ),
                  Text(
                    profile.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.bodyTextSize(
                        context,
                        base: 14,
                        min: 12,
                        max: 17,
                      ),
                      color: theme.colorScheme.onSurface.withValues(alpha: .60),
                    ),
                  ),
                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                    SizedBox(
                      height: Responsive.spacing(
                        context,
                        base: 4,
                        min: 3,
                        max: 7,
                      ),
                    ),
                    Text(
                      profile.phone!,
                      style: TextStyle(
                        fontSize: Responsive.smallTextSize(
                          context,
                          base: 12,
                          min: 10,
                          max: 15,
                        ),
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: .50,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
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

class _Avatar extends StatelessWidget {
  final StudentProfile profile;
  final double radius;

  const _Avatar({required this.profile, required this.radius});

  @override
  Widget build(BuildContext context) {
    final url = profile.profileImageUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }

    final name = profile.fullName.trim();

    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: .12),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * .72,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ============================================================================
// OVERVIEW
// ============================================================================

class _OverviewGrid extends StatelessWidget {
  final StudentProfileAnalytics analytics;

  const _OverviewGrid({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(
      context,
      minItemWidth: 220,
      minColumns: 1,
      maxColumns: 4,
    );

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: Responsive.spacing(context, base: 12, min: 8, max: 18),
      mainAxisSpacing: Responsive.spacing(context, base: 12, min: 8, max: 18),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: columns == 1
          ? 3.0
          : columns == 2
          ? 1.65
          : 1.75,
      children: [
        _StatCard(
          title: 'Lectures Opened',
          value: analytics.lecturesOpened,
          icon: Icons.menu_book_rounded,
        ),
        _StatCard(
          title: 'Audio Completed',
          value: analytics.audioCompleted,
          icon: Icons.audio_file_rounded,
        ),
        _StatCard(
          title: 'Video Completed',
          value: analytics.videoCompleted,
          icon: Icons.video_file_rounded,
        ),
        _StatCard(
          title: 'Exam Attempts',
          value: analytics.examAttempts,
          icon: Icons.quiz_rounded,
        ),
        _StatCard(
          title: 'Average Score',
          value: '${analytics.averageScore.toStringAsFixed(0)}%',
          icon: Icons.analytics_rounded,
        ),
        _StatCard(
          title: 'Best Score',
          value: '${analytics.bestScore.toStringAsFixed(0)}%',
          icon: Icons.emoji_events_rounded,
        ),
        _StatCard(
          title: 'Passed Exams',
          value: analytics.passedExams,
          icon: Icons.check_circle_rounded,
        ),
        _StatCard(
          title: 'Success Rate',
          value: '${analytics.successRate.toStringAsFixed(0)}%',
          icon: Icons.trending_up_rounded,
        ),
        _StatCard(
          title: 'Study Time',
          value: analytics.formattedStudyTime,
          icon: Icons.timer_outlined,
        ),
      ],
    );
  }
}

// ============================================================================
// STAT CARD
// ============================================================================

class _StatCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(
          Responsive.spacing(context, base: 14, min: 10, max: 20),
        ),
        child: Row(
          children: [
            Container(
              width: Responsive.clamped(context, base: 45, min: 40, max: 54),
              height: Responsive.clamped(context, base: 45, min: 40, max: 54),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(
                  Responsive.smallRadius(context),
                ),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: Responsive.iconSize(context, base: 23, min: 20, max: 30),
              ),
            ),
            SizedBox(
              width: Responsive.spacing(context, base: 11, min: 8, max: 16),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.smallTextSize(
                        context,
                        base: 11,
                        min: 10,
                        max: 14,
                      ),
                      color: theme.colorScheme.onSurface.withValues(alpha: .55),
                    ),
                  ),
                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      base: 4,
                      min: 3,
                      max: 6,
                    ),
                  ),
                  Text(
                    value.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.clamped(
                        context,
                        base: 18,
                        min: 16,
                        max: 24,
                      ),
                      fontWeight: FontWeight.w800,
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
// SECTION CARD
// ============================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: Responsive.iconSize(
                    context,
                    base: 21,
                    min: 18,
                    max: 28,
                  ),
                  color: theme.colorScheme.primary,
                ),
                SizedBox(
                  width: Responsive.spacing(context, base: 9, min: 6, max: 14),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: Responsive.titleSize(
                        context,
                        base: 17,
                        min: 15,
                        max: 22,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(
              height: Responsive.spacing(context, base: 16, min: 12, max: 22),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
// ============================================================================
// STUDY ACTIVITY CHART
// ============================================================================

class _StudyActivityChart extends StatefulWidget {
  final List<DailyStudyActivity> activity;

  const _StudyActivityChart({required this.activity});

  @override
  State<_StudyActivityChart> createState() => _StudyActivityChartState();
}

class _StudyActivityChartState extends State<_StudyActivityChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.activity.isEmpty) {
      return _ChartEmptyState(
        icon: Icons.insights_outlined,
        text: 'Study activity will appear here once you start studying.',
      );
    }

    final spots = List.generate(widget.activity.length, (index) {
      return FlSpot(
        index.toDouble(),
        widget.activity[index].studyMinutes.toDouble(),
      );
    });

    final maxValue = widget.activity
        .map((item) => item.studyMinutes.toDouble())
        .fold<double>(0, (current, value) => current > value ? current : value);

    final chartMaxY = maxValue <= 5
        ? 10.0
        : (((maxValue * 1.20) / 5).ceil() * 5).toDouble();

    final chartHeight = Responsive.clamped(
      context,
      base: 280,
      min: 240,
      max: 340,
    );

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: chartMaxY,
              minX: 0,
              maxX: (widget.activity.length - 1).toDouble(),
              clipData: const FlClipData.none(),

              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchSpotThreshold: 28,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: theme.colorScheme.primary,
                            strokeWidth: 3,
                            strokeColor: theme.colorScheme.surface,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((touchedSpot) {
                      final index = touchedSpot.x.round();

                      if (index < 0 || index >= widget.activity.length) {
                        return null;
                      }

                      final item = widget.activity[index];

                      return LineTooltipItem(
                        '${item.studyMinutes.toStringAsFixed(0)} min',
                        TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    }).toList();
                  },
                ),
                touchCallback: (event, response) {
                  if (!mounted) {
                    return;
                  }

                  if (response == null || !event.isInterestedForInteractions) {
                    setState(() {
                      _touchedIndex = null;
                    });
                    return;
                  }

                  final firstSpot = response.lineBarSpots?.isNotEmpty == true
                      ? response.lineBarSpots!.first
                      : null;

                  setState(() {
                    _touchedIndex = firstSpot?.x.round();
                  });
                },
              ),

              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: chartMaxY <= 10 ? 2 : chartMaxY / 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                    strokeWidth: 1,
                  );
                },
              ),

              borderData: FlBorderData(show: false),

              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: chartMaxY / 5,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: Responsive.smallTextSize(
                            context,
                            base: 10,
                            min: 9,
                            max: 12,
                          ),
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.50,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: widget.activity.length > 7 ? 2 : 1,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();

                      if (index < 0 || index >= widget.activity.length) {
                        return const SizedBox.shrink();
                      }

                      final day = widget.activity[index].day;

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${day.day}/${day.month}',
                          style: TextStyle(
                            fontSize: Responsive.smallTextSize(
                              context,
                              base: 9.5,
                              min: 8,
                              max: 12,
                            ),
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.28,
                  barWidth: 3.2,
                  color: theme.colorScheme.primary,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) {
                      if (_touchedIndex == spot.x.round()) {
                        return true;
                      }

                      return spots.length <= 7 ||
                          spot.x == 0 ||
                          spot.x == spots.length - 1;
                    },
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: _touchedIndex == index ? 5.5 : 3.2,
                        color: theme.colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: theme.colorScheme.surface,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.18),
                        theme.colorScheme.primary.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: Responsive.spacing(context, base: 8, min: 6, max: 12)),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Study time per day (minutes)',
            style: TextStyle(
              fontSize: Responsive.smallTextSize(
                context,
                base: 11,
                min: 10,
                max: 14,
              ),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.50),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// EXAM CHART
// ============================================================================

class _ExamChart extends StatefulWidget {
  final List<StudentExamAttempt> attempts;

  const _ExamChart({required this.attempts});

  @override
  State<_ExamChart> createState() => _ExamChartState();
}

class _ExamChartState extends State<_ExamChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final completed = widget.attempts
        .where((item) => item.isCompleted)
        .take(12)
        .toList()
        .reversed
        .toList();

    if (completed.isEmpty) {
      return _ChartEmptyState(
        icon: Icons.analytics_outlined,
        text: 'Completed exam scores will appear here.',
      );
    }

    final spots = List.generate(
      completed.length,
      (index) => FlSpot(index.toDouble(), completed[index].score.toDouble()),
    );

    final passingScore = _inferPassingScore(completed);

    final chartHeight = Responsive.clamped(
      context,
      base: 280,
      min: 240,
      max: 340,
    );

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              minX: 0,
              maxX: (completed.length - 1).toDouble(),

              lineTouchData: LineTouchData(
                enabled: true,
                touchSpotThreshold: 28,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: theme.colorScheme.primary,
                            strokeWidth: 3,
                            strokeColor: theme.colorScheme.surface,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((touchedSpot) {
                      final index = touchedSpot.x.round();

                      if (index < 0 || index >= completed.length) {
                        return null;
                      }

                      return LineTooltipItem(
                        '${completed[index].score}%',
                        TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    }).toList();
                  },
                ),
                touchCallback: (event, response) {
                  if (!mounted) {
                    return;
                  }

                  if (response == null || !event.isInterestedForInteractions) {
                    setState(() {
                      _touchedIndex = null;
                    });
                    return;
                  }

                  final firstSpot = response.lineBarSpots?.isNotEmpty == true
                      ? response.lineBarSpots!.first
                      : null;

                  setState(() {
                    _touchedIndex = firstSpot?.x.round();
                  });
                },
              ),

              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                    strokeWidth: 1,
                  );
                },
              ),

              borderData: FlBorderData(show: false),

              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    interval: 20,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                          fontSize: Responsive.smallTextSize(
                            context,
                            base: 10,
                            min: 9,
                            max: 12,
                          ),
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.50,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: completed.length > 7 ? 2 : 1,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();

                      if (index < 0 || index >= completed.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            fontSize: Responsive.smallTextSize(
                              context,
                              base: 9.5,
                              min: 8,
                              max: 12,
                            ),
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              extraLinesData: passingScore > 0
                  ? ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: passingScore.toDouble(),
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.40,
                          ),
                          strokeWidth: 1.5,
                          dashArray: [6, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.error,
                            ),
                            labelResolver: (line) {
                              return 'Pass $passingScore%';
                            },
                          ),
                        ),
                      ],
                    )
                  : const ExtraLinesData(),

              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.22,
                  barWidth: 3.2,
                  color: theme.colorScheme.primary,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) {
                      return completed.length <= 7 ||
                          spot.x == 0 ||
                          spot.x == completed.length - 1 ||
                          _touchedIndex == spot.x.round();
                    },
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: _touchedIndex == index ? 5.5 : 3.2,
                        color: theme.colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: theme.colorScheme.surface,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.18),
                        theme.colorScheme.primary.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: Responsive.spacing(context, base: 10, min: 7, max: 14),
        ),
        Row(
          children: [
            _ChartLegendDot(color: theme.colorScheme.primary, label: 'Score'),
            const Spacer(),
            if (passingScore > 0)
              _ChartLegendDot(
                color: theme.colorScheme.error,
                label: 'Passing score',
              ),
          ],
        ),
      ],
    );
  }

  int _inferPassingScore(List<StudentExamAttempt> completed) {
    if (completed.isEmpty) {
      return 0;
    }

    final passedScores = completed
        .where((item) => item.passed)
        .map((item) => item.score)
        .toList();

    if (passedScores.isEmpty) {
      return 0;
    }

    return passedScores.reduce((a, b) => a < b ? a : b);
  }
}

// ============================================================================
// CHART LEGEND DOT
// ============================================================================

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: Responsive.spacing(context, base: 6, min: 4, max: 8)),
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.smallTextSize(
              context,
              base: 11,
              min: 10,
              max: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CHART EMPTY
// ============================================================================

class _ChartEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ChartEmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: Responsive.clamped(context, base: 220, min: 180, max: 260),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(Responsive.cardPadding(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: Responsive.clamped(context, base: 54, min: 46, max: 66),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              SizedBox(
                height: Responsive.spacing(context, base: 12, min: 8, max: 18),
              ),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.bodyTextSize(
                    context,
                    base: 13,
                    min: 12,
                    max: 16,
                  ),
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
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
// EXAM ATTEMPTS
// ============================================================================

class _ExamAttemptsList extends StatelessWidget {
  final List<StudentExamAttempt> attempts;

  final void Function(StudentExamAttempt attempt)? onAttemptTap;

  const _ExamAttemptsList({required this.attempts, required this.onAttemptTap});

  @override
  Widget build(BuildContext context) {
    if (attempts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No exam attempts yet.'),
      );
    }

    return Column(
      children: attempts
          .take(15)
          .map(
            (attempt) => _ExamAttemptTile(
              attempt: attempt,
              onTap: onAttemptTap == null ? null : () => onAttemptTap!(attempt),
            ),
          )
          .toList(),
    );
  }
}

// ============================================================================
// EXAM ATTEMPT TILE
// ============================================================================

class _ExamAttemptTile extends StatelessWidget {
  final StudentExamAttempt attempt;
  final VoidCallback? onTap;

  const _ExamAttemptTile({required this.attempt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    late final Color statusColor;
    late final String statusLabel;

    if (attempt.isCompleted) {
      statusColor = attempt.passed ? Colors.green : theme.colorScheme.error;

      statusLabel = attempt.passed ? 'Passed' : 'Failed';
    } else if (attempt.isInProgress) {
      statusColor = theme.colorScheme.primary;

      statusLabel = 'In Progress';
    } else {
      statusColor = Colors.orange;

      statusLabel = 'Abandoned';
    }

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, base: 4, min: 2, max: 8),
      ),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: .10),
        child: Icon(
          attempt.isInProgress
              ? Icons.play_arrow_rounded
              : attempt.passed
              ? Icons.check_rounded
              : Icons.close_rounded,
          color: statusColor,
        ),
      ),
      title: Text(
        attempt.examTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        attempt.isCompleted ? '${attempt.score}% • $statusLabel' : statusLabel,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

// ============================================================================
// LECTURE ACTIVITY
// ============================================================================

class _LectureActivityList extends StatelessWidget {
  final List<StudentLectureActivity> activities;

  final void Function({
    required String moduleId,
    required String moduleName,
    required String lectureId,
  })?
  onOpenLecture;

  const _LectureActivityList({
    required this.activities,
    required this.onOpenLecture,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No lecture activity yet.'),
      );
    }

    return Column(
      children: activities
          .take(15)
          .map(
            (activity) => ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.spacing(
                  context,
                  base: 4,
                  min: 2,
                  max: 8,
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .10),
                child: Icon(Icons.menu_book_rounded, color: AppColors.primary),
              ),
              title: Text(
                activity.lectureTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${activity.moduleName} • '
                '${activity.progressPercent}% progress',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenLecture == null
                  ? null
                  : () {
                      onOpenLecture!(
                        moduleId: activity.moduleId,
                        moduleName: activity.moduleName,
                        lectureId: activity.lectureId,
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

class _StudentSettings extends StatefulWidget {
  const _StudentSettings();

  @override
  State<_StudentSettings> createState() => _StudentSettingsState();
}

class _StudentSettingsState extends State<_StudentSettings> {
  final StudentPreferencesService _preferences =
      StudentPreferencesService.instance;

  bool _loading = true;

  bool _notifications = true;
  bool _autoPlay = true;
  bool _wifiOnlyDownloads = true;

  double _defaultSpeed = 1.0;

  @override
  void initState() {
    super.initState();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final notifications = await _preferences.getNotificationsEnabled();

      final autoPlay = await _preferences.getAutoPlayEnabled();

      final wifiOnly = await _preferences.getWifiOnlyDownloads();

      final speed = await _preferences.getDefaultPlaybackSpeed();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = notifications;
        _autoPlay = autoPlay;
        _wifiOnlyDownloads = wifiOnly;
        _defaultSpeed = speed;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load student settings error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notifications'),
          subtitle: const Text('Receive study and exam reminders.'),
          value: _notifications,
          onChanged: (value) async {
            if (!mounted) {
              return;
            }

            setState(() {
              _notifications = value;
            });

            await _preferences.setNotificationsEnabled(value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto Play Media'),
          subtitle: const Text('Automatically start audio or video.'),
          value: _autoPlay,
          onChanged: (value) async {
            if (!mounted) {
              return;
            }

            setState(() {
              _autoPlay = value;
            });

            await _preferences.setAutoPlayEnabled(value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Wi-Fi Only Downloads'),
          subtitle: const Text('Prevent lecture downloads over mobile data.'),
          value: _wifiOnlyDownloads,
          onChanged: (value) async {
            if (!mounted) {
              return;
            }

            setState(() {
              _wifiOnlyDownloads = value;
            });

            await _preferences.setWifiOnlyDownloads(value);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Default Playback Speed'),
          subtitle: const Text('Used when opening audio lectures.'),
          trailing: DropdownButton<double>(
            value: _defaultSpeed,
            items: const [
              DropdownMenuItem(value: 0.75, child: Text('0.75x')),
              DropdownMenuItem(value: 1.0, child: Text('1.0x')),
              DropdownMenuItem(value: 1.25, child: Text('1.25x')),
              DropdownMenuItem(value: 1.5, child: Text('1.5x')),
              DropdownMenuItem(value: 1.75, child: Text('1.75x')),
              DropdownMenuItem(value: 2.0, child: Text('2.0x')),
            ],
            onChanged: (value) async {
              if (value == null) {
                return;
              }

              if (!mounted) {
                return;
              }

              setState(() {
                _defaultSpeed = value;
              });

              await _preferences.setDefaultPlaybackSpeed(value);
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

class _AccountActions extends StatelessWidget {
  final VoidCallback onPassword;
  final VoidCallback onLogout;

  const _AccountActions({required this.onPassword, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onPassword,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text(
              'Sign Out',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: Responsive.clamped(context, base: 60, min: 50, max: 76),
            ),
            SizedBox(
              height: Responsive.spacing(context, base: 16, min: 10, max: 22),
            ),
            Text(
              'Unable to load profile data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.titleSize(
                  context,
                  base: 18,
                  min: 16,
                  max: 24,
                ),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(
              height: Responsive.spacing(context, base: 16, min: 12, max: 24),
            ),
            SizedBox(
              height: Responsive.buttonHeight(context),
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
