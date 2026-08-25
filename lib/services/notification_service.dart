import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  debugPrint(
    'Background notification: ${message.messageId}',
  );
}

class NotificationService {
  NotificationService._();

  static final NotificationService
      instance =
      NotificationService._();

  final FirebaseMessaging
      _messaging =
      FirebaseMessaging.instance;

  final SupabaseClient
      _supabase =
      Supabase.instance.client;

  final FlutterLocalNotificationsPlugin
      _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>?
      _tokenRefreshSubscription;

  StreamSubscription<
      RemoteMessage>?
      _onMessageSubscription;

  StreamSubscription<
      RemoteMessage>?
      _onMessageOpenedAppSubscription;

  bool _initialized = false;

  String? _registeredUserId;

  // ===========================================================================
  // LIVE UNREAD COUNT
  // ===========================================================================

  final ValueNotifier<int>
      unreadCount =
      ValueNotifier<int>(0);

  // ===========================================================================
  // LECTURE NAVIGATION
  // ===========================================================================

  Future<void> Function(
    String lectureId,
  )? _lectureTapHandler;

  String? _pendingLectureId;

  // ===========================================================================
  // ANDROID CHANNEL
  // ===========================================================================

  static const AndroidNotificationChannel
      _androidChannel =
      AndroidNotificationChannel(
    'medidata_notifications',
    'MediData Notifications',
    description:
        'Notifications from MediData',
    importance:
        Importance.high,
  );

  // ===========================================================================
  // SET LECTURE HANDLER
  // ===========================================================================

  void setLectureTapHandler(
    Future<void> Function(
      String lectureId,
    ) handler,
  ) {
    _lectureTapHandler =
        handler;

    final pending =
        _pendingLectureId;

    if (pending == null ||
        pending.isEmpty) {
      return;
    }

    _pendingLectureId = null;

    unawaited(
      handler(pending),
    );
  }

  // ===========================================================================
  // CLEAR LECTURE HANDLER
  // ===========================================================================

  void clearLectureTapHandler() {
    _lectureTapHandler = null;
  }

  // ===========================================================================
  // TAKE PENDING LECTURE
  // ===========================================================================

  String? takePendingLectureId() {
    final lectureId =
        _pendingLectureId;

    _pendingLectureId = null;

    return lectureId;
  }

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void>
      initialize() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'Notification initialization skipped: '
        'no authenticated user.',
      );
      return;
    }

    if (_initialized &&
        _registeredUserId ==
            user.id) {
      await refreshUnreadCount();
      return;
    }

    try {
      // -----------------------------------------------------------------------
      // BACKGROUND
      // -----------------------------------------------------------------------

      FirebaseMessaging
          .onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      // -----------------------------------------------------------------------
      // LOCAL NOTIFICATIONS
      // -----------------------------------------------------------------------

      await _initializeLocalNotifications();

      // -----------------------------------------------------------------------
      // PERMISSION
      // -----------------------------------------------------------------------

      await _requestPermission();

      // -----------------------------------------------------------------------
      // iOS APNs TOKEN
      // -----------------------------------------------------------------------

      if (!kIsWeb &&
          defaultTargetPlatform ==
              TargetPlatform.iOS) {
        await _waitForApnsToken();
      }

      // -----------------------------------------------------------------------
      // iOS FOREGROUND
      // -----------------------------------------------------------------------

      if (!kIsWeb &&
          defaultTargetPlatform ==
              TargetPlatform.iOS) {
        await _messaging
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // -----------------------------------------------------------------------
      // TOKEN
      // -----------------------------------------------------------------------

      await registerCurrentToken();

      // -----------------------------------------------------------------------
      // UNREAD COUNT
      // -----------------------------------------------------------------------

      await refreshUnreadCount();

      // -----------------------------------------------------------------------
      // TOKEN REFRESH
      // -----------------------------------------------------------------------

      await _tokenRefreshSubscription
          ?.cancel();

      _tokenRefreshSubscription =
          _messaging.onTokenRefresh.listen(
        (token) async {
          await _saveToken(token);
        },
        onError: (error) {
          debugPrint(
            'FCM token refresh error: $error',
          );
        },
      );

      // -----------------------------------------------------------------------
      // FOREGROUND
      // -----------------------------------------------------------------------

      await _onMessageSubscription
          ?.cancel();

      _onMessageSubscription =
          FirebaseMessaging
              .onMessage
              .listen(
        _handleForegroundMessage,
        onError: (error) {
          debugPrint(
            'FCM foreground error: $error',
          );
        },
      );

      // -----------------------------------------------------------------------
      // BACKGROUND TAP
      // -----------------------------------------------------------------------

      await _onMessageOpenedAppSubscription
          ?.cancel();

      _onMessageOpenedAppSubscription =
          FirebaseMessaging
              .onMessageOpenedApp
              .listen(
        _handleNotificationOpen,
        onError: (error) {
          debugPrint(
            'FCM notification open error: $error',
          );
        },
      );

      // -----------------------------------------------------------------------
      // TERMINATED TAP
      // -----------------------------------------------------------------------

      final initialMessage =
          await _messaging
              .getInitialMessage();

      if (initialMessage != null) {
        await _handleNotificationOpen(
          initialMessage,
        );
      }

      _initialized = true;
      _registeredUserId =
          user.id;

      debugPrint(
        'NotificationService initialized '
        'for user ${user.id}',
      );
    } catch (e) {
      _initialized = false;
      _registeredUserId = null;

      debugPrint(
        'Notification initialization error: $e',
      );
    }
  }

  // ===========================================================================
  // LOCAL INITIALIZATION
  // ===========================================================================

  Future<void>
      _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission:
          false,
      requestBadgePermission:
          false,
      requestSoundPermission:
          false,
    );

    const initializationSettings =
        InitializationSettings(
      android:
          androidSettings,
      iOS:
          darwinSettings,
      macOS:
          darwinSettings,
    );

    await _localNotifications
        .initialize(
      settings:
          initializationSettings,
      onDidReceiveNotificationResponse:
          _handleLocalNotificationTap,
    );

    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin
          .createNotificationChannel(
        _androidChannel,
      );
    }
  }

  // ===========================================================================
  // FOREGROUND MESSAGE
  // ===========================================================================

  Future<void>
      _handleForegroundMessage(
    RemoteMessage message,
  ) async {
    final notification =
        message.notification;

    if (notification == null) {
      await refreshUnreadCount();
      return;
    }

    final title =
        notification.title ??
            '';

    final body =
        notification.body ??
            '';

    if (title.isEmpty &&
        body.isEmpty) {
      await refreshUnreadCount();
      return;
    }

    final notificationId =
        message.data[
            'notification_id'];

    final type =
        message.data['type'];

    final lectureId =
        message.data[
            'lecture_id'];

    final payload =
        _buildPayload(
      notificationId:
          notificationId,
      type:
          type,
      lectureId:
          lectureId,
    );

    await _localNotifications
        .show(
      id:
          _notificationIdFromMessage(
        message,
      ),
      title:
          title,
      body:
          body,
      notificationDetails:
          const NotificationDetails(
        android:
            AndroidNotificationDetails(
          'medidata_notifications',
          'MediData Notifications',
          channelDescription:
              'Notifications from MediData',
          importance:
              Importance.high,
          priority:
              Priority.high,
          icon:
              '@mipmap/ic_launcher',
        ),
        iOS:
            DarwinNotificationDetails(
          presentAlert:
              true,
          presentBadge:
              true,
          presentSound:
              true,
        ),
      ),
      payload:
          payload,
    );

    await refreshUnreadCount();
  }

  // ===========================================================================
  // LOCAL TAP
  // ===========================================================================

  Future<void>
      _handleLocalNotificationTap(
    NotificationResponse
        response,
  ) async {
    final payload =
        response.payload;

    if (payload == null ||
        payload.isEmpty) {
      return;
    }

    final data =
        _parsePayload(
      payload,
    );

    final notificationId =
        data[
            'notification_id'];

    final lectureId =
        data['lecture_id'];

    if (notificationId != null &&
        notificationId.isNotEmpty) {
      await markAsRead(
        notificationId,
      );
    }

    if (lectureId != null &&
        lectureId.isNotEmpty) {
      await _openLecture(
        lectureId,
      );
    }
  }

  // ===========================================================================
  // FCM OPEN
  // ===========================================================================

  Future<void>
      _handleNotificationOpen(
    RemoteMessage message,
  ) async {
    final notificationId =
        message.data[
            'notification_id'];

    final lectureId =
        message.data[
            'lecture_id'];

    if (notificationId != null &&
        notificationId.isNotEmpty) {
      await markAsRead(
        notificationId,
      );
    }

    if (lectureId != null &&
        lectureId.isNotEmpty) {
      await _openLecture(
        lectureId,
      );
    }
  }

  // ===========================================================================
  // OPEN LECTURE
  // ===========================================================================

  Future<void> _openLecture(
    String lectureId,
  ) async {
    if (lectureId.trim().isEmpty) {
      return;
    }

    final handler =
        _lectureTapHandler;

    if (handler == null) {
      // AppShell has not registered
      // its navigation handler yet.
      _pendingLectureId =
          lectureId;
      return;
    }

    try {
      await handler(
        lectureId,
      );
    } catch (e) {
      debugPrint(
        'Lecture notification navigation error: $e',
      );
    }
  }

  // ===========================================================================
  // REQUEST PERMISSION
  // ===========================================================================

  Future<void>
      _requestPermission() async {
    try {
      final settings =
          await _messaging
              .requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        'Notification permission: '
        '${settings.authorizationStatus}',
      );

      if (!kIsWeb &&
          defaultTargetPlatform ==
              TargetPlatform.android) {
        final androidPlugin =
            _localNotifications
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint(
        'Notification permission error: $e',
      );
    }
  }

  // ===========================================================================
  // APNs
  // ===========================================================================

  Future<void>
      _waitForApnsToken() async {
    for (int attempt = 0;
        attempt < 10;
        attempt++) {
      try {
        final apnsToken =
            await _messaging
                .getAPNSToken();

        if (apnsToken != null &&
            apnsToken.isNotEmpty) {
          return;
        }
      } catch (e) {
        debugPrint(
          'APNs token error: $e',
        );
      }

      await Future<void>.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );
    }
  }

  // ===========================================================================
  // TOKEN
  // ===========================================================================

  Future<void>
      registerCurrentToken() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final token =
          await _messaging.getToken();

      if (token == null ||
          token.trim().isEmpty) {
        return;
      }

      await _saveToken(
        token,
      );
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
          'user_id':
              user.id,
          'token':
              normalizedToken,
          'platform':
              _platformValue(),
          'updated_at':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        },
        onConflict:
            'user_id,token',
      );
    } catch (e) {
      debugPrint(
        'Save FCM token error: $e',
      );
    }
  }

  // ===========================================================================
  // UNREAD COUNT
  // ===========================================================================

  Future<void>
      refreshUnreadCount() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      unreadCount.value =
          0;
      return;
    }

    try {
      final response =
          await _supabase
              .from(
                'notification_recipients',
              )
              .select('id')
              .eq(
                'user_id',
                user.id,
              )
              .isFilter(
                'read_at',
                null,
              );

      unreadCount.value =
          (response as List)
              .length;
    } catch (e) {
      debugPrint(
        'Unread notification count error: $e',
      );
    }
  }

  // ===========================================================================
  // MARK AS READ
  // ===========================================================================

  Future<void> markAsRead(
    String notificationId,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null ||
        notificationId
            .trim()
            .isEmpty) {
      return;
    }

    try {
      await _supabase
          .from(
            'notification_recipients',
          )
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
          )
          .isFilter(
            'read_at',
            null,
          );

      await refreshUnreadCount();
    } catch (e) {
      debugPrint(
        'Mark notification as read error: $e',
      );
    }
  }

  // ===========================================================================
  // UNREGISTER
  // ===========================================================================

  Future<void>
      unregisterCurrentToken() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      unreadCount.value =
          0;
      return;
    }

    try {
      final token =
          await _messaging.getToken();

      if (token != null &&
          token.trim().isNotEmpty) {
        await _supabase
            .from(
              'device_tokens',
            )
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

      await _messaging
          .deleteToken();

      _initialized = false;
      _registeredUserId =
          null;
      _pendingLectureId =
          null;
      unreadCount.value =
          0;
    } catch (e) {
      debugPrint(
        'Unregister FCM token error: $e',
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

    switch (
        defaultTargetPlatform) {
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
  // PAYLOAD
  // ===========================================================================

  String _buildPayload({
    String? notificationId,
    String? type,
    String? lectureId,
  }) {
    return [
      'notification_id=${Uri.encodeComponent(
        notificationId ?? '',
      )}',
      'type=${Uri.encodeComponent(
        type ?? '',
      )}',
      'lecture_id=${Uri.encodeComponent(
        lectureId ?? '',
      )}',
    ].join('&');
  }

  Map<String, String>
      _parsePayload(
    String payload,
  ) {
    final result =
        <String, String>{};

    for (final pair
        in payload.split('&')) {
      final separator =
          pair.indexOf('=');

      if (separator <= 0) {
        continue;
      }

      final key =
          pair.substring(
        0,
        separator,
      );

      final value =
          Uri.decodeComponent(
        pair.substring(
          separator + 1,
        ),
      );

      result[key] = value;
    }

    return result;
  }

  // ===========================================================================
  // NOTIFICATION ID
  // ===========================================================================

  int _notificationIdFromMessage(
    RemoteMessage message,
  ) {
    final messageId =
        message.messageId;

    if (messageId == null ||
        messageId.isEmpty) {
      return DateTime.now()
          .millisecondsSinceEpoch;
    }

    return messageId.hashCode &
        0x7fffffff;
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

    _tokenRefreshSubscription =
        null;

    _onMessageSubscription =
        null;

    _onMessageOpenedAppSubscription =
        null;

    _initialized = false;

    _registeredUserId =
        null;
  }
}