import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../services/student_preferences_service.dart';
import '../../services/student_profile_service.dart';
import 'contact_support_screen.dart';

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

  Future<_ProfilePageData> _loadData() async {
    final results = await Future.wait([
      _service.getProfile(),
      _service.getAnalytics(),
      _service.getModuleProgress(),
    ]);

    return _ProfilePageData(
      profile: results[0] as StudentProfile,
      analytics: results[1] as StudentProfileAnalytics,
      moduleProgress: results[2] as List<StudentModuleProgress>,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _future = _loadData();
    });

    await _future;
  }

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

        return Padding(
          padding: EdgeInsets.only(
            bottom: Responsive.clamped(context, base: 92, min: 84, max: 105),
          ),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                Responsive.spacing(context, base: 12, min: 8, max: 20),
                horizontalPadding,
                18,
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
                    SizedBox(height: Responsive.spacing(context, base: 10, min: 7, max: 16)),
                    _OverviewGrid(analytics: data.analytics),
                    SizedBox(height: Responsive.spacing(context, base: 12, min: 9, max: 18)),
                    _SectionCard(
                      title: 'Learning Progress',
                      icon: Icons.school_rounded,
                      child: _LearningProgress(modules: data.moduleProgress),
                    ),
                    SizedBox(height: Responsive.spacing(context, base: 12, min: 9, max: 18)),
                    _SectionCard(
                      title: 'Study Activity',
                      icon: Icons.insights_rounded,
                      child: _StudyActivityChart(activity: data.analytics.dailyActivity),
                    ),
                    SizedBox(height: Responsive.spacing(context, base: 12, min: 9, max: 18)),
                    _SectionCard(
                      title: 'Exam Performance',
                      icon: Icons.analytics_rounded,
                      child: _ExamChart(attempts: data.analytics.attempts),
                    ),
                    SizedBox(height: Responsive.spacing(context, base: 12, min: 9, max: 18)),
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
                    SizedBox(height: Responsive.spacing(context, base: 12, min: 9, max: 18)),
                    _SectionCard(
                      title: 'Lecture Activity',
                      icon: Icons.menu_book_rounded,
                      child: _LectureActivityList(
                        activities: data.analytics.lectureActivities,
                        onOpenLecture: widget.onOpenLecture,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, base: 12, min: 9, max: 18)),
                    _SectionCard(
                      title: 'Settings',
                      icon: Icons.settings_rounded,
                      child: const _StudentSettings(),
                    ),
                    SizedBox(height: Responsive.spacing(context, base: 12, min: 9, max: 18)),
                    _AccountActions(
                      onPassword: _showChangePassword,
                      onSupport: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ContactSupportScreen(),
                          ),
                        );
                      },
                      onLogout: _showLogoutDialog,
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

  Future<void> _showEditProfile(StudentProfile profile) async {
    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phone ?? '');
    final emailController = TextEditingController(text: profile.email);
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
                    SizedBox(height: Responsive.spacing(dialogContext, base: 14, min: 10, max: 18)),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(dialogContext, base: 14, min: 10, max: 18)),
                    TextField(
                      readOnly: true,
                      controller: emailController,
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
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          setDialogState(() => saving = true);
                          try {
                            await _service.updateProfile(
                              fullName: name,
                              phone: phoneController.text,
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                          } catch (e) {
                            debugPrint('Update profile error: $e');
                            if (!dialogContext.mounted) return;
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Unable to update profile.')),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    nameController.dispose();
    phoneController.dispose();

    if (!mounted) return;
    await _refresh();
  }

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
                    SizedBox(height: Responsive.spacing(dialogContext, base: 14, min: 10, max: 18)),
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
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final password = passwordController.text;
                          final confirmation = confirmController.text;
                          if (password.length < 6 || password != confirmation) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Check your passwords.')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            await _service.updatePassword(password);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password updated successfully.')),
                            );
                          } catch (e) {
                            debugPrint('Update password error: $e');
                            if (!dialogContext.mounted) return;
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Unable to change password.')),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  Future<void> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: const Text('You will need to sign in again to access your account.'),
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

    if (result != true) return;
    await _service.signOut();
  }
}

class _ProfilePageData {
  final StudentProfile profile;
  final StudentProfileAnalytics analytics;
  final List<StudentModuleProgress> moduleProgress;

  const _ProfilePageData({
    required this.profile,
    required this.analytics,
    required this.moduleProgress,
  });
}

class _ProfileHeader extends StatelessWidget {
  final StudentProfile profile;
  final VoidCallback onEdit;

  const _ProfileHeader({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.cardPadding(context);
    final avatarRadius = Responsive.clamped(context, base: 34, min: 28, max: 46);

    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(profile: profile, radius: avatarRadius),
            SizedBox(width: Responsive.spacing(context, base: 14, min: 10, max: 20)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.titleSize(context, base: 21, min: 18, max: 28),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: Responsive.spacing(context, base: 4, min: 3, max: 7)),
                  Text(
                    profile.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.bodyTextSize(context, base: 14, min: 12, max: 17),
                      color: theme.colorScheme.onSurface.withValues(alpha: .60),
                    ),
                  ),
                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                    SizedBox(height: Responsive.spacing(context, base: 3, min: 2, max: 6)),
                    Text(
                      profile.phone!,
                      style: TextStyle(
                        fontSize: Responsive.smallTextSize(context, base: 12, min: 10, max: 15),
                        color: theme.colorScheme.onSurface.withValues(alpha: .50),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(onPressed: onEdit, tooltip: 'Edit profile', icon: const Icon(Icons.edit_outlined)),
          ],
        ),
      ),
    );
  }
}

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

class _OverviewGrid extends StatelessWidget {
  final StudentProfileAnalytics analytics;

  const _OverviewGrid({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final width = Responsive.width(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final availableWidth = width - (horizontalPadding * 2);
    final int columns;

    if (availableWidth >= 960) {
      columns = 4;
    } else if (availableWidth >= 600) {
      columns = 3;
    } else if (availableWidth >= 420) {
      columns = 2;
    } else {
      columns = 1;
    }

    final spacing = Responsive.spacing(context, base: 8, min: 6, max: 12);
    final itemWidth = (availableWidth - (spacing * (columns - 1))) / columns;
    final itemHeight = columns == 1
        ? Responsive.clamped(context, base: 70, min: 64, max: 78)
        : Responsive.clamped(context, base: 90, min: 80, max: 102);

    final cards = <Widget>[
      _StatCard(title: 'Lectures Opened', value: analytics.lecturesOpened, icon: Icons.menu_book_rounded),
      _StatCard(title: 'Audio Completed', value: analytics.audioCompleted, icon: Icons.audio_file_rounded),
      _StatCard(title: 'Video Completed', value: analytics.videoCompleted, icon: Icons.video_file_rounded),
      _StatCard(title: 'Exam Attempts', value: analytics.examAttempts, icon: Icons.quiz_rounded),
      _StatCard(title: 'Average Score', value: '${analytics.averageScore.toStringAsFixed(0)}%', icon: Icons.analytics_rounded),
      _StatCard(title: 'Best Score', value: '${analytics.bestScore.toStringAsFixed(0)}%', icon: Icons.emoji_events_rounded),
      _StatCard(title: 'Passed Exams', value: analytics.passedExams, icon: Icons.check_circle_rounded),
      _StatCard(title: 'Success Rate', value: '${analytics.successRate.toStringAsFixed(0)}%', icon: Icons.trending_up_rounded),
      _StatCard(title: 'Study Time', value: analytics.formattedStudyTime, icon: Icons.timer_outlined),
    ];

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: cards
          .map((card) => SizedBox(width: itemWidth, height: itemHeight, child: card))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontalPadding = Responsive.spacing(context, base: 9, min: 7, max: 13);
    final verticalPadding = Responsive.spacing(context, base: 6, min: 5, max: 8);
    final iconBoxSize = Responsive.clamped(context, base: 36, min: 32, max: 42);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        child: Row(
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Responsive.smallRadius(context)),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: Responsive.iconSize(context, base: 19, min: 17, max: 24),
              ),
            ),
            SizedBox(width: Responsive.spacing(context, base: 7, min: 5, max: 10)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.smallTextSize(context, base: 9.5, min: 8.5, max: 12),
                      height: 1.05,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.clamped(context, base: 16, min: 14, max: 21),
                      height: 1.0,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(Responsive.clamped(context, base: 13, min: 10, max: 18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: Responsive.iconSize(context, base: 20, min: 17, max: 26), color: theme.colorScheme.primary),
                SizedBox(width: Responsive.spacing(context, base: 7, min: 5, max: 12)),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: Responsive.titleSize(context, base: 16, min: 14, max: 21),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: Responsive.spacing(context, base: 9, min: 7, max: 14)),
            child,
          ],
        ),
      ),
    );
  }
}

class _LearningProgress extends StatelessWidget {
  final List<StudentModuleProgress> modules;

  const _LearningProgress({required this.modules});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (modules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Learning progress will appear here once lectures are available.'),
      );
    }

    final modulesWithLectures = modules.where((module) => module.totalLectures > 0).toList();
    final totalLectures = modulesWithLectures.fold<int>(0, (sum, module) => sum + module.totalLectures);
    final completedLectures = modulesWithLectures.fold<int>(0, (sum, module) => sum + module.completedLectures);
    final overallProgress = totalLectures == 0 ? 0 : ((completedLectures / totalLectures) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Progress', style: TextStyle(fontSize: Responsive.bodyTextSize(context, base: 13, min: 12, max: 16), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '$completedLectures of $totalLectures lectures completed',
                    style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 11, min: 10, max: 14), color: theme.colorScheme.onSurface.withValues(alpha: .55)),
                  ),
                ],
              ),
            ),
            Text('$overallProgress%', style: TextStyle(fontSize: Responsive.titleSize(context, base: 22, min: 19, max: 28), fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
          ],
        ),
        SizedBox(height: Responsive.spacing(context, base: 8, min: 6, max: 12)),
        ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.smallRadius(context)),
          child: LinearProgressIndicator(value: overallProgress / 100, minHeight: Responsive.clamped(context, base: 8, min: 7, max: 10)),
        ),
        if (modulesWithLectures.isNotEmpty) ...[
          SizedBox(height: Responsive.spacing(context, base: 16, min: 12, max: 22)),
          Text('Modules', style: TextStyle(fontSize: Responsive.bodyTextSize(context, base: 13, min: 12, max: 16), fontWeight: FontWeight.w800)),
          SizedBox(height: Responsive.spacing(context, base: 8, min: 6, max: 12)),
          ...modulesWithLectures.map((module) => _ModuleProgressTile(module: module)),
        ],
      ],
    );
  }
}

class _ModuleProgressTile extends StatelessWidget {
  final StudentModuleProgress module;

  const _ModuleProgressTile({required this.module});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = module.progressPercent / 100;
    final isComplete = module.progressPercent >= 100;

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.spacing(context, base: 11, min: 8, max: 15)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  module.moduleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: Responsive.bodyTextSize(context, base: 12.5, min: 11, max: 15), fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: Responsive.spacing(context, base: 8, min: 6, max: 12)),
              Text('${module.completedLectures}/${module.totalLectures}', style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 10.5, min: 9, max: 13), color: theme.colorScheme.onSurface.withValues(alpha: .50))),
              SizedBox(width: Responsive.spacing(context, base: 7, min: 5, max: 10)),
              Text('${module.progressPercent}%', style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 11, min: 10, max: 14), fontWeight: FontWeight.w800, color: isComplete ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, base: 5, min: 4, max: 8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.smallRadius(context)),
            child: LinearProgressIndicator(value: progress, minHeight: Responsive.clamped(context, base: 6, min: 5, max: 8)),
          ),
        ],
      ),
    );
  }
}

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
      return _ChartEmptyState(icon: Icons.insights_outlined, text: 'Study activity will appear here once you start studying.');
    }

    final spots = List.generate(widget.activity.length, (index) => FlSpot(index.toDouble(), widget.activity[index].studyMinutes.toDouble()));
    final maxValue = widget.activity.map((item) => item.studyMinutes.toDouble()).fold<double>(0, (current, value) => current > value ? current : value);
    final chartMaxY = maxValue <= 5 ? 10.0 : (((maxValue * 1.20) / 5).ceil() * 5).toDouble();
    final chartHeight = Responsive.clamped(context, base: 220, min: 185, max: 270);

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
                touchSpotThreshold: 22,
                getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes.map((index) => TouchedSpotIndicatorData(FlLine(color: theme.colorScheme.primary.withValues(alpha: .25), strokeWidth: 1.2, dashArray: [5, 5]), FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 5.5, color: theme.colorScheme.primary, strokeWidth: 2.5, strokeColor: theme.colorScheme.surface)))).toList(),
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  getTooltipItems: (touchedSpots) => touchedSpots.map((touchedSpot) {
                    final index = touchedSpot.x.round();
                    if (index < 0 || index >= widget.activity.length) return null;
                    final item = widget.activity[index];
                    return LineTooltipItem('${item.studyMinutes.toStringAsFixed(0)} min', TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w800));
                  }).toList(),
                ),
                touchCallback: (event, response) {
                  if (response == null || !event.isInterestedForInteractions) {
                    if (_touchedIndex != null) setState(() => _touchedIndex = null);
                    return;
                  }
                  final firstSpot = response.lineBarSpots?.isNotEmpty == true ? response.lineBarSpots!.first : null;
                  final nextIndex = firstSpot?.x.round();
                  if (_touchedIndex != nextIndex) setState(() => _touchedIndex = nextIndex);
                },
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: chartMaxY <= 10 ? 2 : chartMaxY / 5, getDrawingHorizontalLine: (value) => FlLine(color: theme.colorScheme.onSurface.withValues(alpha: .06), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: chartMaxY / 5, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 9, min: 8, max: 12), color: theme.colorScheme.onSurface.withValues(alpha: .45)))),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: widget.activity.length > 7 ? 2 : 1, reservedSize: 28, getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= widget.activity.length) return const SizedBox.shrink();
                  final day = widget.activity[index].day;
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${day.day}/${day.month}', style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 9, min: 8, max: 12), color: theme.colorScheme.onSurface.withValues(alpha: .50))));
                })),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: .28,
                  barWidth: 3,
                  color: theme.colorScheme.primary,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  dotData: FlDotData(show: true, checkToShowDot: (spot, barData) => _touchedIndex == spot.x.round() || spots.length <= 7 || spot.x == 0 || spot.x == spots.length - 1, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: _touchedIndex == index ? 5 : 2.8, color: theme.colorScheme.primary, strokeWidth: 2, strokeColor: theme.colorScheme.surface)),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.colorScheme.primary.withValues(alpha: .14), theme.colorScheme.primary.withValues(alpha: .01)])),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Align(alignment: Alignment.centerLeft, child: Text('Study time per day (minutes)', style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 10.5, min: 9, max: 13), color: theme.colorScheme.onSurface.withValues(alpha: .48)))),
      ],
    );
  }
}

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
    final completed = widget.attempts.where((item) => item.isCompleted).take(12).toList().reversed.toList();
    if (completed.isEmpty) return _ChartEmptyState(icon: Icons.analytics_outlined, text: 'Completed exam scores will appear here.');

    final spots = List.generate(completed.length, (index) => FlSpot(index.toDouble(), completed[index].score.toDouble()));
    final commonPassingScore = _resolveCommonPassingScore(completed);
    final chartHeight = Responsive.clamped(context, base: 220, min: 185, max: 270);

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
                touchSpotThreshold: 22,
                getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes.map((index) => TouchedSpotIndicatorData(FlLine(color: theme.colorScheme.primary.withValues(alpha: .25), strokeWidth: 1.2, dashArray: [5, 5]), FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 5.5, color: theme.colorScheme.primary, strokeWidth: 2.5, strokeColor: theme.colorScheme.surface)))).toList(),
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  getTooltipItems: (touchedSpots) => touchedSpots.map((touchedSpot) {
                    final index = touchedSpot.x.round();
                    if (index < 0 || index >= completed.length) return null;
                    final attempt = completed[index];
                    return LineTooltipItem('${attempt.score}%\n${attempt.examTitle}', TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w800));
                  }).toList(),
                ),
                touchCallback: (event, response) {
                  if (response == null || !event.isInterestedForInteractions) {
                    if (_touchedIndex != null) setState(() => _touchedIndex = null);
                    return;
                  }
                  final firstSpot = response.lineBarSpots?.isNotEmpty == true ? response.lineBarSpots!.first : null;
                  final nextIndex = firstSpot?.x.round();
                  if (_touchedIndex != nextIndex) setState(() => _touchedIndex = nextIndex);
                },
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (value) => FlLine(color: theme.colorScheme.onSurface.withValues(alpha: .06), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 20, getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 9, min: 8, max: 12), color: theme.colorScheme.onSurface.withValues(alpha: .45)))),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: completed.length > 7 ? 2 : 1, reservedSize: 27, getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= completed.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text('#${index + 1}', style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 9, min: 8, max: 12), color: theme.colorScheme.onSurface.withValues(alpha: .50))));
                })),
              ),
              extraLinesData: commonPassingScore != null ? ExtraLinesData(horizontalLines: [HorizontalLine(y: commonPassingScore.toDouble(), color: theme.colorScheme.error.withValues(alpha: .40), strokeWidth: 1.5, dashArray: [6, 5], label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: theme.colorScheme.error), labelResolver: (line) => 'Pass $commonPassingScore%') )]) : const ExtraLinesData(),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: .22,
                  barWidth: 3,
                  color: theme.colorScheme.primary,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  dotData: FlDotData(show: true, checkToShowDot: (spot, barData) => completed.length <= 7 || spot.x == 0 || spot.x == completed.length - 1 || _touchedIndex == spot.x.round(), getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: _touchedIndex == index ? 5 : 2.8, color: theme.colorScheme.primary, strokeWidth: 2, strokeColor: theme.colorScheme.surface)),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.colorScheme.primary.withValues(alpha: .14), theme.colorScheme.primary.withValues(alpha: .01)])),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            _ChartLegendDot(color: theme.colorScheme.primary, label: 'Score'),
            const Spacer(),
            if (commonPassingScore != null)
              _ChartLegendDot(color: theme.colorScheme.error, label: 'Passing score')
            else
              Text('Passing score varies by exam', style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 10, min: 9, max: 13), color: theme.colorScheme.onSurface.withValues(alpha: .45))),
          ],
        ),
      ],
    );
  }

  int? _resolveCommonPassingScore(List<StudentExamAttempt> attempts) {
    if (attempts.isEmpty) return null;
    final scores = attempts.map((attempt) => attempt.passingScore).where((score) => score > 0 && score <= 100).toSet();
    if (scores.length != 1) return null;
    return scores.first;
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 10.5, min: 9, max: 14))),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ChartEmptyState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: Responsive.clamped(context, base: 170, min: 145, max: 210),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(Responsive.clamped(context, base: 14, min: 10, max: 20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: Responsive.clamped(context, base: 46, min: 40, max: 58), color: theme.colorScheme.onSurface.withValues(alpha: .22)),
              const SizedBox(height: 10),
              Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.bodyTextSize(context, base: 12, min: 11, max: 15), height: 1.35, color: theme.colorScheme.onSurface.withValues(alpha: .58))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamAttemptsList extends StatelessWidget {
  final List<StudentExamAttempt> attempts;
  final void Function(StudentExamAttempt attempt)? onAttemptTap;
  const _ExamAttemptsList({required this.attempts, required this.onAttemptTap});

  @override
  Widget build(BuildContext context) {
    if (attempts.isEmpty) {
      return const Padding(padding: EdgeInsets.all(10), child: Text('No exam attempts yet.'));
    }
    return Column(
      children: attempts.map((attempt) => _ExamAttemptTile(attempt: attempt, onTap: onAttemptTap == null ? null : () => onAttemptTap!(attempt))).toList(),
    );
  }
}

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
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(backgroundColor: statusColor.withValues(alpha: .10), child: Icon(attempt.isInProgress ? Icons.play_arrow_rounded : attempt.passed ? Icons.check_rounded : Icons.close_rounded, color: statusColor)),
      title: Text(attempt.examTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(attempt.isCompleted ? '${attempt.score}% • $statusLabel' : statusLabel),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _LectureActivityList extends StatelessWidget {
  final List<StudentLectureActivity> activities;
  final void Function({required String moduleId, required String moduleName, required String lectureId})? onOpenLecture;
  const _LectureActivityList({required this.activities, required this.onOpenLecture});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Padding(padding: EdgeInsets.all(10), child: Text('No lecture activity yet.'));
    return Column(
      children: activities.map((activity) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: .10), child: Icon(Icons.menu_book_rounded, color: AppColors.primary)),
        title: Text(activity.lectureTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${activity.moduleName} • ${activity.progressPercent}% progress'),
        trailing: onOpenLecture == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onOpenLecture == null ? null : () => onOpenLecture!(moduleId: activity.moduleId, moduleName: activity.moduleName, lectureId: activity.lectureId),
      )).toList(),
    );
  }
}

class _StudentSettings extends StatefulWidget {
  const _StudentSettings();
  @override
  State<_StudentSettings> createState() => _StudentSettingsState();
}

class _StudentSettingsState extends State<_StudentSettings> {
  final StudentPreferencesService _preferences = StudentPreferencesService.instance;
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
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _autoPlay = autoPlay;
        _wifiOnlyDownloads = wifiOnly;
        _defaultSpeed = speed;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load student settings error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator()));
    }

    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Notifications'),
          subtitle: const Text('Receive study and exam reminders.'),
          value: _notifications,
          onChanged: (value) async {
            setState(() => _notifications = value);
            await _preferences.setNotificationsEnabled(value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Auto Play Media'),
          subtitle: const Text('Automatically start audio or video.'),
          value: _autoPlay,
          onChanged: (value) async {
            setState(() => _autoPlay = value);
            await _preferences.setAutoPlayEnabled(value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Wi-Fi Only Downloads'),
          subtitle: const Text('Prevent lecture downloads over mobile data.'),
          value: _wifiOnlyDownloads,
          onChanged: (value) async {
            setState(() => _wifiOnlyDownloads = value);
            await _preferences.setWifiOnlyDownloads(value);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
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
              if (value == null) return;
              setState(() => _defaultSpeed = value);
              await _preferences.setDefaultPlaybackSpeed(value);
            },
          ),
        ),
      ],
    );
  }
}

class _AccountActions extends StatelessWidget {
  final VoidCallback onPassword;
  final VoidCallback onSupport;
  final VoidCallback onLogout;

  const _AccountActions({
    required this.onPassword,
    required this.onSupport,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, base: 4, min: 2, max: 8)),
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onPassword,
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, base: 4, min: 2, max: 8)),
            leading: Icon(Icons.support_agent_rounded, color: theme.colorScheme.primary),
            title: const Text('Contact Support'),
            subtitle: const Text('Send a message to the support team.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onSupport,
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, base: 4, min: 2, max: 8)),
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700)),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

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
            Icon(Icons.cloud_off_rounded, size: Responsive.clamped(context, base: 56, min: 48, max: 72)),
            const SizedBox(height: 12),
            Text(
              'Unable to load profile data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.titleSize(context, base: 18, min: 16, max: 24), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: Responsive.buttonHeight(context),
              child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')),
            ),
          ],
        ),
      ),
    );
  }
}
