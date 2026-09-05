import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/student_notification_service.dart';
import 'exam_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final Future<void> Function(String lectureId)? onLectureTap;

  const NotificationsScreen({
    super.key,
    this.onLectureTap,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final StudentNotificationService _service =
      StudentNotificationService.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<List<StudentNotification>> _notificationsFuture;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<StudentNotification>> _loadNotifications() async {
    final notifications = await _service.getNotifications();
    if (mounted) {
      setState(() {
        _unreadCount = notifications.where((n) => !n.isRead).length;
      });
    }
    return notifications;
  }

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
    await _notificationsFuture;
  }

  Future<void> _openNotification(StudentNotification notification) async {
    if (!notification.isRead) {
      try {
        await _service.markAsRead(notification.id);
        if (mounted) {
          setState(() {
            _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          });
        }
      } catch (_) {
        _showMessage('Unable to update notification.');
      }
    }

    final lectureId = notification.lectureId?.trim();
    if (lectureId != null && lectureId.isNotEmpty) {
      if (widget.onLectureTap != null) {
        await widget.onLectureTap!(lectureId);
      }
      return;
    }

    final examId = notification.examId?.trim();
    if (examId != null && examId.isNotEmpty) {
      await _openExam(examId);
    }
  }

  Future<void> _openExam(String examId) async {
    try {
      final response = await _supabase
          .from('exams')
          .select('id, title, duration_minutes, passing_score, is_active')
          .eq('id', examId)
          .maybeSingle();

      if (!mounted) return;

      if (response == null || response['is_active'] != true) {
        _showMessage('This exam is no longer available.');
        return;
      }

      final exam = Map<String, dynamic>.from(response);
      final id = exam['id']?.toString();
      if (id == null || id.isEmpty) {
        _showMessage('Unable to open this exam.');
        return;
      }

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
      debugPrint('Open notification exam error: $e');
      if (mounted) {
        _showMessage('Unable to open this exam.');
      }
    }
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0) return;
    try {
      await _service.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _unreadCount = 0;
        _notificationsFuture = _loadNotifications();
      });
    } catch (_) {
      _showMessage('Unable to mark notifications as read.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final difference = DateTime.now().difference(local);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<StudentNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(onRetry: _refresh);
          }

          final notifications = snapshot.data ?? const <StudentNotification>[];
          if (notifications.isEmpty) return const _EmptyView();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  formattedDate: _formatDate(notification.createdAt),
                  onTap: () => _openNotification(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final StudentNotification notification;
  final String formattedDate;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.formattedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLecture = notification.lectureId != null;
    final isExam = notification.examId != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: notification.isRead
                ? theme.colorScheme.surface
                : theme.colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? theme.dividerColor
                  : theme.colorScheme.primary.withValues(alpha: 0.20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExam
                        ? Icons.assignment_rounded
                        : isLecture
                            ? Icons.menu_book_rounded
                            : Icons.notifications_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(left: 8, top: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        notification.body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(formattedDate, style: theme.textTheme.bodySmall),
                          if (isLecture || isExam) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isExam ? 'Exam' : 'Lecture',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 18),
            const Text(
              'No notifications yet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'You will find your updates and reminders here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 60, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            const Text(
              'Unable to load notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
