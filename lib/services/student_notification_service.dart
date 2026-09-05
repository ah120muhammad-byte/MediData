import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

class StudentNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? lectureId;
  final String? examId;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? deliveredAt;

  const StudentNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.lectureId,
    this.examId,
    this.readAt,
    this.deliveredAt,
  });

  bool get isRead => readAt != null;

  factory StudentNotification.fromMap(Map<String, dynamic> map) {
    return StudentNotification(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'general',
      lectureId: map['lecture_id']?.toString(),
      examId: map['exam_id']?.toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.now(),
      readAt: map['read_at'] == null
          ? null
          : DateTime.tryParse(map['read_at'].toString()),
      deliveredAt: map['delivered_at'] == null
          ? null
          : DateTime.tryParse(map['delivered_at'].toString()),
    );
  }
}

class StudentNotificationService {
  StudentNotificationService._();

  static final StudentNotificationService instance =
      StudentNotificationService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService =
      NotificationService.instance;

  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    return user.id;
  }

  Future<List<StudentNotification>> getNotifications() async {
    final userId = _currentUserId;

    final response = await _supabase
        .from('notification_recipients')
        .select('''
          id,
          notification_id,
          user_id,
          read_at,
          delivered_at,
          created_at,
          notifications!inner(
            id,
            title,
            body,
            type,
            lecture_id,
            exam_id,
            created_at
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final result = <StudentNotification>[];

    for (final row in response as List) {
      final map = Map<String, dynamic>.from(row);
      final notificationRaw = map['notifications'];
      if (notificationRaw == null) {
        continue;
      }

      final notificationMap =
          Map<String, dynamic>.from(notificationRaw as Map);

      result.add(
        StudentNotification.fromMap({
          ...notificationMap,
          'read_at': map['read_at'],
          'delivered_at': map['delivered_at'],
        }),
      );
    }

    return result;
  }

  Future<int> getUnreadCount() async {
    final userId = _currentUserId;
    final response = await _supabase
        .from('notification_recipients')
        .select('id')
        .eq('user_id', userId)
        .isFilter('read_at', null);
    return (response as List).length;
  }

  Future<void> markAsRead(String notificationId) async {
    final userId = _currentUserId;
    if (notificationId.trim().isEmpty) {
      return;
    }

    await _supabase
        .from('notification_recipients')
        .update({
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('notification_id', notificationId)
        .eq('user_id', userId)
        .isFilter('read_at', null);

    await _notificationService.refreshUnreadCount();
  }

  Future<void> markAllAsRead() async {
    final userId = _currentUserId;

    await _supabase
        .from('notification_recipients')
        .update({
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .isFilter('read_at', null);

    await _notificationService.refreshUnreadCount();
  }

  Future<void> deleteNotificationForCurrentUser(String notificationId) async {
    final userId = _currentUserId;
    if (notificationId.trim().isEmpty) {
      return;
    }

    await _supabase
        .from('notification_recipients')
        .delete()
        .eq('notification_id', notificationId)
        .eq('user_id', userId);

    await _notificationService.refreshUnreadCount();
  }
}
