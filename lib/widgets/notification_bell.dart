import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/main/exam_screen.dart';
import '../screens/main/notifications_screen.dart';
import '../services/notification_service.dart';

class NotificationBell extends StatefulWidget {
  final Future<void> Function(String lectureId)? onLectureTap;

  const NotificationBell({
    super.key,
    this.onLectureTap,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final NotificationService _service = NotificationService.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _service.setExamTapHandler(_openExamFromNotification);
    _service.refreshUnreadCount();
  }

  @override
  void dispose() {
    _service.clearExamTapHandler();
    super.dispose();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          onLectureTap: widget.onLectureTap,
        ),
      ),
    );

    if (!mounted) return;
    await _service.refreshUnreadCount();
  }

  Future<void> _openExamFromNotification(String examId) async {
    final normalizedExamId = examId.trim();
    if (normalizedExamId.isEmpty || !mounted) return;

    try {
      final response = await _supabase
          .from('exams')
          .select('id, title, duration_minutes, passing_score, is_active')
          .eq('id', normalizedExamId)
          .maybeSingle();

      if (!mounted) return;

      if (response == null || response['is_active'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This exam is no longer available.')),
        );
        return;
      }

      final exam = Map<String, dynamic>.from(response);
      final id = exam['id']?.toString();
      if (id == null || id.isEmpty) return;

      final title = exam['title']?.toString() ?? 'Exam';
      final duration = (exam['duration_minutes'] as num?)?.toInt() ?? 0;
      final passingScore = (exam['passing_score'] as num?)?.toInt() ?? 0;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamScreen(
            examId: id,
            examTitle: title,
            durationMinutes: duration,
            passingScore: passingScore,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Exam notification navigation error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this exam.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _service.unreadCount,
      builder: (context, unreadCount, _) {
        return IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotifications,
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
