import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../services/student_preferences_service.dart';
import '../../services/student_profile_service.dart';
import 'contact_support_screen.dart';

const String _supportEmail = 'support@medidata.app';

class ProfileScreen extends StatefulWidget {
  final void Function({required String moduleId, required String moduleName, required String lectureId})? onOpenLecture;
  final void Function(StudentExamAttempt attempt)? onExamAttemptTap;
  final VoidCallback? onOpenExamHistory;
  const ProfileScreen({super.key, this.onOpenLecture, this.onExamAttemptTap, this.onOpenExamHistory});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StudentProfileService _service = StudentProfileService.instance;
  late Future<_ProfilePageData> _future;
  @override void initState() { super.initState(); _future = _loadData(); }
  Future<_ProfilePageData> _loadData() async {
    final results = await Future.wait([_service.getProfile(), _service.getAnalytics(), _service.getModuleProgress()]);
    return _ProfilePageData(profile: results[0] as StudentProfile, analytics: results[1] as StudentProfileAnalytics, moduleProgress: results[2] as List<StudentModuleProgress>);
  }
  Future<void> _refresh() async { if (!mounted) return; final future = _loadData(); setState(() => _future = future); await future; }
  void _openSupport() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactSupportScreen()));
  Future<void> _sendSupportEmail() async {
    final profile = await _service.getProfile();
    final subject = Uri.encodeComponent('MediData Support Request');
    final body = Uri.encodeComponent('Hello MediData Support Team,\n\nStudent: ${profile.fullName}\nEmail: ${profile.email}\n\nMessage:\n');
    final uri = Uri.parse('mailto:$_supportEmail?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) { await launchUrl(uri); return; }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Support Email'),
      content: const SelectableText(_supportEmail),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }
  @override Widget build(BuildContext context) {
    return FutureBuilder<_ProfilePageData>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError || snapshot.data == null) return _ErrorView(onRetry: _refresh);
      final data = snapshot.data!; final horizontalPadding = Responsive.horizontalPadding(context);
      return Padding(padding: EdgeInsets.only(bottom: Responsive.clamped(context, base: 92, min: 84, max: 105)), child: RefreshIndicator(onRefresh: _refresh, child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), padding: EdgeInsets.fromLTRB(horizontalPadding, Responsive.spacing(context, base: 12, min: 8, max: 20), horizontalPadding, 18), child: Responsive.constrained(context, maxWidth: 1100, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _ProfileHeader(profile: data.profile, onEdit: () => _showEditProfile(data.profile)), _Gap(),
        _OverviewGrid(analytics: data.analytics), _Gap(),
        _SectionCard(title: 'Learning Progress', icon: Icons.school_rounded, child: _LearningProgress(modules: data.moduleProgress)), _Gap(),
        _SectionCard(title: 'Study Activity', icon: Icons.insights_rounded, child: _StudyActivityChart(activity: data.analytics.dailyActivity)), _Gap(),
        _SectionCard(title: 'Exam Performance', icon: Icons.analytics_rounded, child: _ExamChart(attempts: data.analytics.attempts)), _Gap(),
        _SectionCard(title: 'Exam Attempts', icon: Icons.history_rounded, trailing: widget.onOpenExamHistory == null ? null : TextButton(onPressed: widget.onOpenExamHistory, child: const Text('View All')), child: _ExamAttemptsList(attempts: data.analytics.attempts, onAttemptTap: widget.onExamAttemptTap)), _Gap(),
        _SectionCard(title: 'Lecture Activity', icon: Icons.menu_book_rounded, child: _LectureActivityList(activities: data.analytics.lectureActivities, onOpenLecture: widget.onOpenLecture)), _Gap(),
        _SectionCard(title: 'Settings', icon: Icons.settings_rounded, child: const _StudentSettings()), _Gap(),
        _AccountActions(onPassword: _showChangePassword, onSupport: _openSupport, onSupportEmail: _sendSupportEmail, onLogout: _showLogoutDialog),
      ]))));
    });
  }

  Future<void> _showEditProfile(StudentProfile profile) async {
    final nameController = TextEditingController(text: profile.fullName), phoneController = TextEditingController(text: profile.phone ?? ''), emailController = TextEditingController(text: profile.email); bool saving = false;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(title: const Text('Edit Profile'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nameController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded))), const SizedBox(height: 14), TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))), const SizedBox(height: 14), TextField(readOnly: true, controller: emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)))])), actions: [TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')), FilledButton(onPressed: saving ? null : () async { final name = nameController.text.trim(); if (name.isEmpty) return; setDialogState(() => saving = true); try { await _service.updateProfile(fullName: name, phone: phoneController.text); if (!dialogContext.mounted) return; Navigator.of(dialogContext).pop(); } catch (_) { if (!dialogContext.mounted) return; setDialogState(() => saving = false); ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Unable to update profile.'))); } }, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'))]));
    nameController.dispose(); phoneController.dispose(); emailController.dispose(); if (mounted) await _refresh();
  }
  Future<void> _showChangePassword() async {
    final passwordController = TextEditingController(), confirmController = TextEditingController(); bool saving = false;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(title: const Text('Change Password'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_outline_rounded))), const SizedBox(height: 14), TextField(controller: confirmController, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_outline_rounded)))]), actions: [TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')), FilledButton(onPressed: saving ? null : () async { final password = passwordController.text, confirmation = confirmController.text; if (password.length < 6 || password != confirmation) { ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Check your passwords.'))); return; } setDialogState(() => saving = true); try { await _service.updatePassword(password); if (!dialogContext.mounted) return; Navigator.of(dialogContext).pop(); } catch (_) { if (!dialogContext.mounted) return; setDialogState(() => saving = false); ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Unable to change password.'))); } }, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update'))]));
    passwordController.dispose(); confirmController.dispose();
  }
  Future<void> _showLogoutDialog() async { final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Sign Out?'), content: const Text('You will need to sign in again to access your account.'), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Sign Out'))])); if (result == true) await _service.signOut(); }
}

class _Gap extends StatelessWidget { @override Widget build(BuildContext context) => SizedBox(height: Responsive.spacing(context, base: 12, min: 9, max: 18)); }

class _ProfilePageData { final StudentProfile profile; final StudentProfileAnalytics analytics; final List<StudentModuleProgress> moduleProgress; const _ProfilePageData({required this.profile, required this.analytics, required this.moduleProgress}); }

class _ProfileHeader extends StatelessWidget { final StudentProfile profile; final VoidCallback onEdit; const _ProfileHeader({required this.profile, required this.onEdit}); @override Widget build(BuildContext context) { final theme = Theme.of(context), padding = Responsive.cardPadding(context), radius = Responsive.clamped(context, base: 34, min: 28, max: 46); return Card(elevation: 0, child: Padding(padding: EdgeInsets.all(padding), child: Row(children: [_Avatar(profile: profile, radius: radius), SizedBox(width: Responsive.spacing(context, base: 14, min: 10, max: 20)), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: Responsive.titleSize(context, base: 21, min: 18, max: 28), fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(profile.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .60))), if (profile.phone != null && profile.phone!.isNotEmpty) ...[const SizedBox(height: 3), Text(profile.phone!, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .50)))]])), IconButton(onPressed: onEdit, tooltip: 'Edit profile', icon: const Icon(Icons.edit_outlined))]))); } }
class _Avatar extends StatelessWidget { final StudentProfile profile; final double radius; const _Avatar({required this.profile, required this.radius}); @override Widget build(BuildContext context) { final url = profile.profileImageUrl?.trim(); if (url != null && url.isNotEmpty) return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url)); final name = profile.fullName.trim(), initial = name.isEmpty ? '?' : name[0].toUpperCase(); return CircleAvatar(radius: radius, backgroundColor: AppColors.primary.withValues(alpha: .12), child: Text(initial, style: TextStyle(fontSize: radius * .72, fontWeight: FontWeight.w800, color: AppColors.primary))); } }

class _AccountActions extends StatelessWidget {
  final VoidCallback onPassword; final VoidCallback onSupport; final VoidCallback onSupportEmail; final VoidCallback onLogout;
  const _AccountActions({required this.onPassword, required this.onSupport, required this.onSupportEmail, required this.onLogout});
  @override Widget build(BuildContext context) => Card(elevation: 0, child: Column(children: [ListTile(leading: const Icon(Icons.lock_outline_rounded), title: const Text('Change Password'), onTap: onPassword), const Divider(height: 1), ListTile(leading: const Icon(Icons.support_agent_rounded), title: const Text('Contact Support'), subtitle: const Text('Send a support message from the app'), onTap: onSupport), const Divider(height: 1), ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email Support'), subtitle: const Text(_supportEmail), onTap: onSupportEmail), const Divider(height: 1), ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('Sign Out'), onTap: onLogout)]));
}
