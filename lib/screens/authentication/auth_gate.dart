import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../main/app_shell.dart';
import 'login_screen.dart';


class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _notificationInitialized = false;
  String? _initializedUserId;

  Future<void> _initializeNotifications(
    String userId,
  ) async {
    if (_notificationInitialized &&
        _initializedUserId == userId) {
      return;
    }

    try {
      await NotificationService.instance.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationInitialized = true;
        _initializedUserId = userId;
      });
    } catch (e) {
      debugPrint(
        'Notification initialization error: $e',
      );

      // Notification failure must never prevent
      // the student from entering the app.
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationInitialized = false;
        _initializedUserId = userId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        // =====================================================================
        // NOT LOGGED IN
        // =====================================================================

        if (session == null) {
          return const LoginScreen();
        }

        // =====================================================================
        // LOGGED IN
        // =====================================================================

        unawaited(
          _initializeNotifications(
            session.user.id,
          ),
        );

        return const AppShell();
      },
    );
  }
}