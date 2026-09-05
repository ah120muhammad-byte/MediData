import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../services/student_profile_service.dart';
import 'contact_support_screen.dart';

const String _supportEmail = 'support@medidata.app';

class ProfileScreen extends StatefulWidget {
  final void Function({required String moduleId, required String moduleName, required String lectureId})? onOpenLecture;
  final void Function(StudentExamAttempt attempt)? onExamAttemptTap;
  final VoidCallback? onOpenExamHistory;

  const ProfileScreen({super.key, this.onOpenLecture, this.onExamAttemptTap, this.onOpenExamHistory});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StudentProfileService _service = StudentProfileService.instance;
  late Future<StudentProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _service.getProfile();
  }

  Future<void> _refresh() async {
    final future = _service.getProfile();
    setState(() => _profileFuture = future);
    await future;
  }

  void _openSupport() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactSupportScreen()));
  }

  Future<void> _sendSupportEmail(StudentProfile profile) async {
    final subject = Uri.encodeComponent('MediData Support Request');
    final body = Uri.encodeComponent('Hello MediData Support Team,\n\nStudent: ${profile.fullName}\nEmail: ${profile.email}\n\nMessage:\n');
    final uri = Uri.parse('mailto:$_supportEmail?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Email'),
        content: const SelectableText(_supportEmail),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _editProfile(StudentProfile profile) async {
    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phone ?? '');
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded))),
            const SizedBox(height: 14),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 14),
            TextField(readOnly: true, controller: TextEditingController(text: profile.email), decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          ]),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                setDialogState(() => saving = true);
                try {
                  await _service.updateProfile(fullName: name, phone: phoneController.text.trim());
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {
                  if (dialogContext.mounted) {
                    setDialogState(() => saving = false);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Unable to update profile.')));
                  }
                }
              },
              child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (mounted) await _refresh();
  }

  Future<void> _changePassword() async {
    final password = TextEditingController();
    final confirm = TextEditingController();
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_outline_rounded))),
            const SizedBox(height: 14),
            TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_outline_rounded))),
          ]),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: saving ? null : () async {
              if (password.text.length < 6 || password.text != confirm.text) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Check your passwords.')));
                return;
              }
              setDialogState(() => saving = true);
              try {
                await _service.updatePassword(password.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (_) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Unable to change password.')));
                }
              }
            }, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update')),
          ],
        ),
      ),
    );
    password.dispose();
    confirm.dispose();
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Sign Out?'),
      content: const Text('You will need to sign in again to access your account.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out'))],
    ));
    if (result == true) await _service.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = Responsive.horizontalPadding(context);
    return FutureBuilder<StudentProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')));
        }
        final profile = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 30),
            children: [
              Card(elevation: 0, child: Padding(padding: EdgeInsets.all(Responsive.cardPadding(context)), child: Row(children: [
                CircleAvatar(radius: 34, backgroundColor: AppColors.primary.withValues(alpha: .12), backgroundImage: profile.profileImageUrl?.trim().isNotEmpty == true ? NetworkImage(profile.profileImageUrl!.trim()) : null, child: profile.profileImageUrl?.trim().isNotEmpty == true ? null : Text(profile.fullName.isEmpty ? '?' : profile.fullName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(profile.email, maxLines: 1, overflow: TextOverflow.ellipsis), if (profile.phone?.isNotEmpty == true) Text(profile.phone!)])),
                IconButton(onPressed: () => _editProfile(profile), icon: const Icon(Icons.edit_outlined)),
              ]))),
              const SizedBox(height: 14),
              Card(elevation: 0, child: Column(children: [
                const ListTile(leading: Icon(Icons.account_circle_outlined), title: Text('Account')),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.lock_outline_rounded), title: const Text('Change Password'), onTap: _changePassword),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.support_agent_rounded), title: const Text('Contact Support'), subtitle: const Text('Send a support message from the app'), onTap: _openSupport),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email Support'), subtitle: const Text(_supportEmail), onTap: () => _sendSupportEmail(profile)),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('Sign Out'), onTap: _logout),
              ])),
            ],
          ),
        );
      },
    );
  }
}
