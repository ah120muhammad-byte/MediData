import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../services/student_preferences_service.dart';
import '../../services/student_profile_service.dart';
import '../../services/theme_mode_service.dart';
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
    final columns = available >= 900 ? 4 : available >= 560 ? 2 : 1;
    final spacing = Responsive.spacing(context, base: 10, min: 8, max: 14);
    final cards = [
      _StatCard(
        title: 'Study Hours',
        value: '${analytics.totalStudyHours}',
        icon: Icons.timer_outlined,
      ),
      _StatCard(
        title: 'Lectures',
        value: '${analytics.totalLecturesCompleted}',
        icon: Icons.menu_book_rounded,
      ),
      _StatCard(
        title: 'Exams',
        value: '${analytics.totalExamsCompleted}',
        icon: Icons.quiz_rounded,
      ),
      _StatCard(
        title: 'Average Score',
        value: '${analytics.averageExamScore.toStringAsFixed(0)}%',
        icon: Icons.trending_up_rounded,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: columns == 1 ? 3.8 : 2.1,
      ),
      itemBuilder: (_, index) => cards[index],
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
  final ThemeModeService _themeService = ThemeModeService.instance;

  bool _loading = true;
  bool _notifications = true;
  bool _autoPlay = true;
  bool _wifiOnlyDownloads = true;
  double _defaultSpeed = 1.0;

  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _themeMode = _themeService.themeMode;
    _themeService.addListener(_onThemeChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() => _themeMode = _themeService.themeMode);
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
        _themeMode = _themeService.themeMode;
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.brightness_6_rounded),
          title: const Text('App Theme'),
          subtitle: Text(_themeService.label),
          trailing: DropdownButton<ThemeMode>(
            value: _themeMode,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('Light'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('Dark'),
              ),
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Device'),
              ),
            ],
            onChanged: (mode) {
              if (mode == null) return;
              unawaited(_themeService.setThemeMode(mode));
            },
          ),
        ),
        const Divider(height: 1),
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