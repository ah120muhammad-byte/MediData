import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../../services/remote_app_settings_service.dart';
import '../main/app_shell.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class AuthGateV2 extends StatefulWidget {
  final RemoteAppSettings settings;
  const AuthGateV2({super.key, required this.settings});
  @override State<AuthGateV2> createState() => _AuthGateV2State();
}

class _AuthGateV2State extends State<AuthGateV2> {
  final _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _sub;
  bool _passwordRecovery = false;
  bool _notificationStarted = false;

  @override
  void initState() {
    super.initState();
    _sub = _supabase.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() => _passwordRecovery = state.event == AuthChangeEvent.passwordRecovery);
    });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  Future<void> _initNotifications() async {
    if (_notificationStarted || !widget.settings.notificationsEnabled) return;
    _notificationStarted = true;
    try { await NotificationService.instance.initialize(); } catch (e) { debugPrint('Notification init error: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    if (s.maintenanceMode) return _RemoteBlock(title: 'Maintenance', message: s.maintenanceMessage, icon: Icons.build_circle_outlined, supportEmail: s.supportEmail);
    if (s.forceUpdate) return _RemoteBlock(title: 'Update required', message: 'A newer version of ${s.appName} is required. Please update the app to continue.', icon: Icons.system_update_alt_rounded, supportEmail: s.supportEmail);
    if (_passwordRecovery) return const ResetPasswordScreen();

    final session = _supabase.auth.currentSession;
    if (session == null) return _StudentLoginEntry(allowRegistration: s.allowRegistration);

    unawaited(_initNotifications());
    final shell = const AppShell();
    if (s.homeAnnouncement.trim().isEmpty) return shell;
    return Column(children: [
      Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(s.homeAnnouncement)),
          ]),
        )),
      ),
      const Expanded(child: AppShell()),
    ]);
  }
}

class _StudentLoginEntry extends StatelessWidget {
  final bool allowRegistration;
  const _StudentLoginEntry({required this.allowRegistration});
  @override Widget build(BuildContext context) {
    // The existing login screen remains the canonical authentication UI.
    // Registration is additionally guarded at the remote-settings layer by
    // opening a small policy notice when registration is disabled.
    return _RegistrationAwareLogin(allowRegistration: allowRegistration);
  }
}

class _RegistrationAwareLogin extends StatelessWidget {
  final bool allowRegistration;
  const _RegistrationAwareLogin({required this.allowRegistration});
  @override Widget build(BuildContext context) {
    if (allowRegistration) return const LoginScreen();
    return Stack(children: [
      const LoginScreen(),
      Positioned(
        left: 0, right: 0, bottom: 0,
        child: SafeArea(top: false, child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 8),
              const Expanded(child: Text('New account registration is currently disabled by the administrator.')),
            ]),
          ),
        )),
      ),
    ]);
  }
}

class _RemoteBlock extends StatelessWidget {
  final String title, message, supportEmail;
  final IconData icon;
  const _RemoteBlock({required this.title, required this.message, required this.icon, required this.supportEmail});
  @override Widget build(BuildContext context) {
    final t = Theme.of(context); final s = t.colorScheme;
    return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon,size:56,color:s.primary),const SizedBox(height:18),Text(title,style:t.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w700),textAlign:TextAlign.center),const SizedBox(height:10),Text(message,textAlign:TextAlign.center),if(supportEmail.trim().isNotEmpty) ...[const SizedBox(height:12),Text('Support: $supportEmail',textAlign:TextAlign.center,style:t.textTheme.bodySmall)],])))))));
  }
}
