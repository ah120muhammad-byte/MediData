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
  })? onOpenLecture;

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
    if (!mounted) return;
    final future = _loadData();
    setState(() => _future = future);
    await future;
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfilePageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _ErrorView(onRetry: _refresh);
        }

        final data = snapshot.data!;
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
                    _Gap(),
                    _OverviewGrid(analytics: data.analytics),
                    _Gap(),
                    _SectionCard(
                      title: 'Learning Progress',
                      icon: Icons.school_rounded,
                      child: _LearningProgress(modules: data.moduleProgress),
                    ),
                    _Gap(),
                    _SectionCard(
                      title: 'Study Activity',
                      icon: Icons.insights_rounded,
                      child: _StudyActivityChart(
                        activity: data.analytics.dailyActivity,
                      ),
                    ),
                    _Gap(),
                    _SectionCard(
                      title: 'Exam Performance',
                      icon: Icons.analytics_rounded,
                      child: _ExamChart(attempts: data.analytics.attempts),
                    ),
                    _Gap(),
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
                    _Gap(),
                    _SectionCard(
                      title: 'Lecture Activity',
                      icon: Icons.menu_book_rounded,
                      child: _LectureActivityList(
                        activities: data.analytics.lectureActivities,
                        onOpenLecture: widget.onOpenLecture,
                      ),
                    ),
                    _Gap(),
                    _SectionCard(
                      title: 'Settings',
                      icon: Icons.settings_rounded,
                      child: const _StudentSettings(),
                    ),
                    _Gap(),
                    _AccountActions(
                      onPassword: _showChangePassword,
                      onSupport: _openSupport,
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
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                          if (name.isEmpty) return;

                          setDialogState(() => saving = true);
                          try {
                            await _service.updateProfile(
                              fullName: name,
                              phone: phoneController.text,
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => saving = false);
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
    emailController.dispose();

    if (mounted) await _refresh();
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
              content: Column(
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
                  const SizedBox(height: 14),
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
                          final password = passwordController.text;
                          final confirmation = confirmController.text;

                          if (password.length < 6 || password != confirmation) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Check your passwords.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => saving = true);
                          try {
                            await _service.updatePassword(password);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => saving = false);
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
      builder: (dialogContext) => AlertDialog(
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
      ),
    );

    if (result == true) await _service.signOut();
  }
}

class _Gap extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
        height: Responsive.spacing(context, base: 12, min: 9, max: 18),
      );
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
    final radius = Responsive.clamped(context, base: 34, min: 28, max: 46);

    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          children: [
            _Avatar(profile: profile, radius: radius),
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
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: .60),
                    ),
                  ),
                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      profile.phone!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: .50),
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
    final padding = Responsive.horizontalPadding(context);
    final available = width - (padding * 2);
    final columns = available >= 960
        ? 4
        : available >= 600
            ? 3
            : available >= 420
                ? 2
                : 1;
    final spacing = Responsive.spacing(context, base: 8, min: 6, max: 12);
    final itemWidth = (available - spacing * (columns - 1)) / columns;
    final itemHeight = columns == 1
        ? 70.0
        : Responsive.clamped(context, base: 90, min: 80, max: 102);

    final cards = <Widget>[
      _StatCard('Lectures Opened', analytics.lecturesOpened, Icons.menu_book_rounded),
      _StatCard('Audio Completed', analytics.audioCompleted, Icons.audio_file_rounded),
      _StatCard('Video Completed', analytics.videoCompleted, Icons.video_file_rounded),
      _StatCard('Exam Attempts', analytics.examAttempts, Icons.quiz_rounded),
      _StatCard('Average Score', '${analytics.averageScore.toStringAsFixed(0)}%', Icons.analytics_rounded),
      _StatCard('Best Score', '${analytics.bestScore.toStringAsFixed(0)}%', Icons.emoji_events_rounded),
      _StatCard('Passed Exams', analytics.passedExams, Icons.check_circle_rounded),
      _StatCard('Success Rate', '${analytics.successRate.toStringAsFixed(0)}%', Icons.trending_up_rounded),
      _StatCard('Study Time', analytics.formattedStudyTime, Icons.timer_outlined),
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

  const _StatCard(this.title, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 19),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: .55),
                    ),
                  ),
                  Text(
                    value.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
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
        padding: EdgeInsets.all(Responsive.clamped(context, base: 13, min: 10, max: 18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: Responsive.titleSize(context, base: 16, min: 14, max: 21),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 9),
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
    final active = modules.where((m) => m.totalLectures > 0).toList();
    if (active.isEmpty) {
      return const Text('Learning progress will appear here once lectures are available.');
    }

    final total = active.fold<int>(0, (sum, m) => sum + m.totalLectures);
    final done = active.fold<int>(0, (sum, m) => sum + m.completedLectures);
    final overall = total == 0 ? 0 : ((done / total) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$done of $total lectures completed',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: .55),
                ),
              ),
            ),
            Text(
              '$overall%',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: overall / 100, minHeight: 8),
        ),
        const SizedBox(height: 16),
        ...active.map((module) => _ModuleProgressTile(module: module)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  module.moduleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text('${module.completedLectures}/${module.totalLectures}'),
              const SizedBox(width: 7),
              Text(
                '${module.progressPercent}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: module.progressPercent >= 100
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 6),
          ),
        ],
      ),
    );
  }
}

class _StudyActivityChart extends StatelessWidget {
  final List<DailyStudyActivity> activity;
  const _StudyActivityChart({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (activity.isEmpty) {
      return const _ChartEmptyState(
        icon: Icons.insights_outlined,
        text: 'Study activity will appear here once you start studying.',
      );
    }

    final spots = List.generate(
      activity.length,
      (index) => FlSpot(index.toDouble(), activity[index].studyMinutes.toDouble()),
    );
    final maxValue = activity.fold<double>(
      0,
      (current, item) => current > item.studyMinutes ? current : item.studyMinutes.toDouble(),
    );
    final maxY = maxValue <= 5 ? 10.0 : ((maxValue * 1.2) / 5).ceil() * 5.0;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          minX: 0,
          maxX: (activity.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: maxY / 5,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 9),
                ),
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
                interval: activity.length > 7 ? 2 : 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= activity.length) {
                    return const SizedBox.shrink();
                  }
                  final day = activity[index].day;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${day.day}/${day.month}', style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: theme.colorScheme.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: .14),
                    theme.colorScheme.primary.withValues(alpha: .01),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamChart extends StatelessWidget {
  final List<StudentExamAttempt> attempts;
  const _ExamChart({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = attempts.where((a) => a.isCompleted).take(12).toList().reversed.toList();
    if (completed.isEmpty) {
      return const _ChartEmptyState(
        icon: Icons.analytics_outlined,
        text: 'Completed exam scores will appear here.',
      );
    }

    final spots = List.generate(
      completed.length,
      (index) => FlSpot(index.toDouble(), completed[index].score.toDouble()),
    );

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: (completed.length - 1).toDouble(),
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 20,
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
                reservedSize: 27,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= completed.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('#${index + 1}', style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: theme.colorScheme.primary,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: .14),
                    theme.colorScheme.primary.withValues(alpha: .01),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
      height: 170,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: theme.colorScheme.onSurface.withValues(alpha: .22)),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .58)),
            ),
          ],
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
    if (attempts.isEmpty) return const Text('No exam attempts yet.');
    return Column(
      children: attempts
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

class _ExamAttemptTile extends StatelessWidget {
  final StudentExamAttempt attempt;
  final VoidCallback? onTap;
  const _ExamAttemptTile({required this.attempt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color statusColor;
    final String statusLabel;

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
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _LectureActivityList extends StatelessWidget {
  final List<StudentLectureActivity> activities;
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
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Text('No lecture activity yet.');

    return Column(
      children: activities
          .map(
            (activity) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .10),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
              ),
              title: Text(
                activity.lectureTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${activity.moduleName} • ${activity.progressPercent}% progress',
              ),
              trailing: onOpenLecture == null
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: onOpenLecture == null
                  ? null
                  : () => onOpenLecture!(
                        moduleId: activity.moduleId,
                        moduleName: activity.moduleName,
                        lectureId: activity.lectureId,
                      ),
            ),
          )
          .toList(),
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onPassword,
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            leading: Icon(
              Icons.support_agent_rounded,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Contact Support'),
            subtitle: const Text('Send a message to the support team.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onSupport,
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
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

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56),
          const SizedBox(height: 12),
          const Text(
            'Unable to load profile data.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
