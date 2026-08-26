import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/notification_service.dart';
import '../main/app_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
  });

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState
    extends State<AuthGate> {
  // ===========================================================================
  // NOTIFICATION STATE
  // ===========================================================================

  bool _notificationInitialized =
      false;

  String? _initializedUserId;

  // ===========================================================================
  // NOTIFICATION INITIALIZATION
  // ===========================================================================

  Future<void> _initializeNotifications(
    String userId,
  ) async {
    if (_notificationInitialized &&
        _initializedUserId ==
            userId) {
      return;
    }

    try {
      await NotificationService
          .instance
          .initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationInitialized =
            true;

        _initializedUserId =
            userId;
      });
    } catch (e) {
      debugPrint(
        'Notification initialization error: $e',
      );

      // -----------------------------------------------------------------------
      // Notification failure must never
      // prevent the student from opening
      // the application.
      // -----------------------------------------------------------------------

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationInitialized =
            false;

        _initializedUserId =
            userId;
      });
    }
  }

  // ===========================================================================
  // EMAIL CONFIRMATION
  // ===========================================================================

  bool _isUserAllowedIntoApp(
    User user,
  ) {
    // -------------------------------------------------------------------------
    // OAuth providers such as Google are already
    // authenticated by the provider.
    // -------------------------------------------------------------------------

    final provider =
        user.appMetadata['provider']
            ?.toString()
            .toLowerCase();

    if (provider != null &&
        provider != 'email') {
      return true;
    }

    // -------------------------------------------------------------------------
    // Email/password users must have a confirmed
    // email address.
    // -------------------------------------------------------------------------

    return user.emailConfirmedAt !=
        null;
  }

  // ===========================================================================
  // FORCE SIGN OUT FOR UNCONFIRMED SESSION
  // ===========================================================================

  Future<void>
      _handleUnconfirmedUser(
    User user,
  ) async {
    debugPrint(
      'Blocking unconfirmed account: ${user.id}',
    );

    try {
      await NotificationService
          .instance
          .unregisterCurrentToken();
    } catch (e) {
      debugPrint(
        'Unconfirmed token cleanup error: $e',
      );
    }

    try {
      await Supabase.instance.client
          .auth
          .signOut();
    } catch (e) {
      debugPrint(
        'Unconfirmed user sign out error: $e',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationInitialized =
          false;

      _initializedUserId =
          null;
    });
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final supabase =
        Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream:
          supabase.auth.onAuthStateChange,
      builder:
          (
        context,
        snapshot,
      ) {
        final session =
            supabase.auth.currentSession;

        // =====================================================================
        // NOT LOGGED IN
        // =====================================================================

        if (session == null) {
          return const LoginScreen();
        }

        final user =
            session.user;

        // =====================================================================
        // EMAIL CONFIRMATION
        // =====================================================================

        if (!_isUserAllowedIntoApp(
          user,
        )) {
          unawaited(
            _handleUnconfirmedUser(
              user,
            ),
          );

          return const _AuthCheckingView(
            message:
                'Please confirm your email address before continuing.',
          );
        }

        // =====================================================================
        // NOTIFICATIONS
        // =====================================================================

        unawaited(
          _initializeNotifications(
            user.id,
          ),
        );

        // =====================================================================
        // APP
        // =====================================================================

        return const AppShell();
      },
    );
  }
}

// ============================================================================
// AUTH CHECKING VIEW
// ============================================================================

class _AuthCheckingView
    extends StatelessWidget {
  final String message;

  const _AuthCheckingView({
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child:
            Center(
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              24,
            ),
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const SizedBox(
                  width:
                      36,
                  height:
                      36,
                  child:
                      CircularProgressIndicator(),
                ),

                const SizedBox(
                  height:
                      24,
                ),

                Text(
                  'Checking account',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize:
                        20,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                      8,
                ),

                Text(
                  message,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        theme
                            .colorScheme
                            .onSurface
                            .withValues(
                      alpha:
                          0.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}