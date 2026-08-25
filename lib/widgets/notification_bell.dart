import 'package:flutter/material.dart';
import '../screens/main/notifications_screen.dart';
import '../services/notification_service.dart';

class NotificationBell
    extends StatefulWidget {
  final Future<void> Function(
    String lectureId,
  )? onLectureTap;

  const NotificationBell({
    super.key,
    this.onLectureTap,
  });

  @override
  State<NotificationBell>
      createState() =>
          _NotificationBellState();
}

class _NotificationBellState
    extends State<NotificationBell> {
  final NotificationService
      _service =
      NotificationService.instance;

  @override
  void initState() {
    super.initState();

    _service.refreshUnreadCount();
  }

  Future<void>
      _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NotificationsScreen(
          onLectureTap:
              widget.onLectureTap,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _service
        .refreshUnreadCount();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable:
          _service.unreadCount,
      builder: (
        context,
        unreadCount,
        _,
      ) {
        return IconButton(
          tooltip:
              'Notifications',
          onPressed:
              _openNotifications,
          icon: Badge(
            isLabelVisible:
                unreadCount > 0,
            label: Text(
              unreadCount > 99
                  ? '99+'
                  : '$unreadCount',
            ),
            child:
                const Icon(
              Icons
                  .notifications_outlined,
            ),
          ),
        );
      },
    );
  }
}