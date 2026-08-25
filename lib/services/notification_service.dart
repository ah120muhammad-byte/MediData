import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  debugPrint(
    'Background notification: ${message.messageId}',
  );

  // FCM displays notification payloads automatically
  // when the application is in the background.
  //
  // Keep this handler lightweight.
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final SupabaseClient _supabase =
      Supabase.instance.client;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>?
      _onMessageOpenedAppSubscription;

  bool _initialized = false;

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    // -------------------------------------------------------------------------
    // Background messages
    // -------------------------------------------------------------------------

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // -------------------------------------------------------------------------
    // Permission
    // -------------------------------------------------------------------------

    await _requestPermission();

    // -------------------------------------------------------------------------
    // Register current token
    // -------------------------------------------------------------------------

    await registerCurrentToken();

    // -------------------------------------------------------------------------
    // Token refresh
    // -------------------------------------------------------------------------

    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        await _saveToken(token);
      },
      onError: (error) {
        debugPrint(
          'FCM token refresh error: $error',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Foreground notification
    // -------------------------------------------------------------------------

    _onMessageSubscription =
        FirebaseMessaging.onMessage.listen(
      (message) {
        debugPrint(
          'Foreground notification: '
          '${message.notification?.title}',
        );
      },
      onError: (error) {
        debugPrint(
          'FCM foreground message error: $error',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Notification opened from background
    // -------------------------------------------------------------------------

    _onMessageOpenedAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationOpen,
      onError: (error) {
        debugPrint(
          'FCM notification open error: $error',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Notification opened while app was terminated
    // -------------------------------------------------------------------------

    final initialMessage =
        await FirebaseMessaging.instance
            .getInitialMessage();

    if (initialMessage != null) {
      await _handleNotificationOpen(
        initialMessage,
      );
    }
  }

  // ===========================================================================
  // REQUEST PERMISSION
  // ===========================================================================

  Future<void> _requestPermission() async {
    try {
      final settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        'Notification permission: '
        '${settings.authorizationStatus}',
      );
    } catch (e) {
      debugPrint(
        'Notification permission error: $e',
      );
    }
  }

  // ===========================================================================
  // REGISTER CURRENT TOKEN
  // ===========================================================================

  Future<void> registerCurrentToken() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'Skipping FCM token registration: '
        'no authenticated user.',
      );
      return;
    }

    try {
      final token =
          await _messaging.getToken();

      if (token == null ||
          token.trim().isEmpty) {
        debugPrint(
          'FCM did not return a token.',
        );
        return;
      }

      await _saveToken(token);
    } catch (e) {
      debugPrint(
        'FCM token registration error: $e',
      );
    }
  }

  // ===========================================================================
  // SAVE TOKEN
  // ===========================================================================

  Future<void> _saveToken(
    String token,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final normalizedToken =
        token.trim();

    if (normalizedToken.isEmpty) {
      return;
    }

    try {
      await _supabase
          .from('device_tokens')
          .upsert(
        {
          'user_id': user.id,
          'token': normalizedToken,
          'platform': _platformValue(),
          'updated_at':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        },
        onConflict:
            'user_id,token',
      );

      debugPrint(
        'FCM token saved successfully.',
      );
    } catch (e) {
      debugPrint(
        'Save FCM token error: $e',
      );
    }
  }

  // ===========================================================================
  // PLATFORM
  // ===========================================================================

  String _platformValue() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';

      case TargetPlatform.iOS:
        return 'ios';

      case TargetPlatform.macOS:
        return 'macos';

      case TargetPlatform.windows:
        return 'windows';

      case TargetPlatform.linux:
        return 'linux';

      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  // ===========================================================================
  // HANDLE NOTIFICATION OPEN
  // ===========================================================================

  Future<void> _handleNotificationOpen(
    RemoteMessage message,
  ) async {
    final notificationId =
        message.data['notification_id'];

    final lectureId =
        message.data['lecture_id'];

    final type =
        message.data['type'];

    debugPrint(
      'Notification opened: '
      'id=$notificationId, '
      'type=$type, '
      'lecture=$lectureId',
    );

    if (notificationId != null &&
        notificationId.isNotEmpty) {
      await markAsRead(notificationId);
    }

    // Navigation will be connected to
    // the application's navigator/router later.
    //
    // Example:
    // if (lectureId != null) {
    //   navigateToLecture(lectureId);
    // }
  }

  // ===========================================================================
  // MARK AS READ
  // ===========================================================================

  Future<void> markAsRead(
    String notificationId,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await _supabase
          .from('notification_recipients')
          .update(
        {
          'read_at':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        },
      )
          .eq(
        'notification_id',
        notificationId,
      )
          .eq(
        'user_id',
        user.id,
      );
    } catch (e) {
      debugPrint(
        'Mark notification as read error: $e',
      );
    }
  }

  // ===========================================================================
  // DELETE CURRENT TOKEN
  // ===========================================================================

  Future<void> unregisterCurrentToken() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final token =
          await _messaging.getToken();

      if (token != null &&
          token.trim().isNotEmpty) {
        await _supabase
            .from('device_tokens')
            .delete()
            .eq(
              'user_id',
              user.id,
            )
            .eq(
              'token',
              token,
            );
      }

      await _messaging.deleteToken();
    } catch (e) {
      debugPrint(
        'Unregister FCM token error: $e',
      );
    }
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  Future<void> dispose() async {
    await _tokenRefreshSubscription
        ?.cancel();

    await _onMessageSubscription
        ?.cancel();

    await _onMessageOpenedAppSubscription
        ?.cancel();

    _tokenRefreshSubscription = null;
    _onMessageSubscription = null;
    _onMessageOpenedAppSubscription = null;

    _initialized = false;
  }
}