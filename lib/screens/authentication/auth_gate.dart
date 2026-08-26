import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../services/notification_service.dart';
import '../main/app_shell.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

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
  final SupabaseClient _supabase =
      Supabase.instance.client;

  StreamSubscription<AuthState>?
      _authSubscription;

  bool _notificationInitialized =
      false;

  bool _notificationInitializing =
      false;

  String? _initializedUserId;

  bool _isPasswordRecovery =
      false;

  bool _handlingUnconfirmedUser =
      false;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        _supabase.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint(
          'Auth state change error: $error',
        );

        debugPrintStack(
          stackTrace: stackTrace,
        );
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;

    super.dispose();
  }

  // ==========================================================================
  // AUTH STATE
  // ==========================================================================

  void _handleAuthStateChange(
    AuthState state,
  ) {
    if (!mounted) {
      return;
    }

    final event =
        state.event;

    debugPrint(
      'Auth state changed: $event',
    );

    setState(() {
      _isPasswordRecovery =
          event ==
              AuthChangeEvent
                  .passwordRecovery;
    });

    if (event ==
        AuthChangeEvent.signedOut) {
      setState(() {
        _notificationInitialized =
            false;

        _notificationInitializing =
            false;

        _initializedUserId =
            null;

        _handlingUnconfirmedUser =
            false;
      });

      return;
    }

    if (event ==
            AuthChangeEvent
                .signedIn ||
        event ==
            AuthChangeEvent
                .tokenRefreshed ||
        event ==
            AuthChangeEvent
                .userUpdated) {
      final user =
          state.session?.user;

      if (user == null) {
        return;
      }

      if (!_isUserAllowedIntoApp(
        user,
      )) {
        unawaited(
          _handleUnconfirmedUser(
            user,
          ),
        );
      }
    }
  }

  // ==========================================================================
  // EMAIL CONFIRMATION
  // ==========================================================================

  bool _isUserAllowedIntoApp(
    User user,
  ) {
    return user.emailConfirmedAt !=
        null;
  }

  // ==========================================================================
  // BLOCK UNCONFIRMED
  // ==========================================================================

  Future<void>
      _handleUnconfirmedUser(
    User user,
  ) async {
    if (_handlingUnconfirmedUser) {
      return;
    }

    _handlingUnconfirmedUser =
        true;

    try {
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
        await _supabase.auth.signOut();
      } catch (e) {
        debugPrint(
          'Unconfirmed sign out error: $e',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationInitialized =
            false;

        _notificationInitializing =
            false;

        _initializedUserId =
            null;

        _isPasswordRecovery =
            false;
      });
    } finally {
      _handlingUnconfirmedUser =
          false;
    }
  }

  // ==========================================================================
  // NOTIFICATIONS
  // ==========================================================================

  Future<void>
      _initializeNotifications(
    String userId,
  ) async {
    if (_notificationInitialized &&
        _initializedUserId ==
            userId) {
      return;
    }

    if (_notificationInitializing) {
      return;
    }

    _notificationInitializing =
        true;

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

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationInitialized =
            false;

        _initializedUserId =
            userId;
      });
    } finally {
      _notificationInitializing =
          false;
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    // ------------------------------------------------------------------------
    // PASSWORD RECOVERY
    // ------------------------------------------------------------------------

    if (_isPasswordRecovery) {
      return const ResetPasswordScreen();
    }

    // ------------------------------------------------------------------------
    // SESSION
    // ------------------------------------------------------------------------

    final session =
        _supabase.auth.currentSession;

    // ------------------------------------------------------------------------
    // LOGGED OUT
    // ------------------------------------------------------------------------

    if (session == null) {
      return const LoginScreen();
    }

    final user =
        session.user;

    // ------------------------------------------------------------------------
    // EMAIL NOT CONFIRMED
    // ------------------------------------------------------------------------

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

    // ------------------------------------------------------------------------
    // NOTIFICATIONS
    // ------------------------------------------------------------------------

    unawaited(
      _initializeNotifications(
        user.id,
      ),
    );

    // ------------------------------------------------------------------------
    // APPLICATION
    // ------------------------------------------------------------------------

    return const AppShell();
  }
}

// ============================================================================
// CHECKING VIEW
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
      body:
          SafeArea(
        child:
            Center(
          child:
              SingleChildScrollView(
            padding:
                EdgeInsets.all(
              Responsive.cardPadding(
                context,
              ),
            ),
            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth:
                    560,
              ),
              child:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  SizedBox(
                    width:
                        Responsive.clamped(
                      context,
                      base:
                          38,
                      min:
                          32,
                      max:
                          48,
                    ),
                    height:
                        Responsive.clamped(
                      context,
                      base:
                          38,
                      min:
                          32,
                      max:
                          48,
                    ),
                    child:
                        const CircularProgressIndicator(),
                  ),
                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          24,
                      min:
                          16,
                      max:
                          32,
                    ),
                  ),
                  Text(
                    'Checking account',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.titleSize(
                        context,
                        base:
                            20,
                        min:
                            18,
                        max:
                            26,
                      ),
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          10,
                      min:
                          7,
                      max:
                          14,
                    ),
                  ),
                  Text(
                    message,
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.bodyTextSize(
                        context,
                        base:
                            14,
                        min:
                            12,
                        max:
                            17,
                      ),
                      height:
                          1.4,
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
      ),
    );
  }
}