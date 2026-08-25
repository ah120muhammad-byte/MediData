import 'package:flutter/material.dart';

import '../../services/student_notification_service.dart';

class NotificationsScreen
    extends StatefulWidget {
  final Future<void> Function(
    String lectureId,
  )? onLectureTap;

  const NotificationsScreen({
    super.key,
    this.onLectureTap,
  });

  @override
  State<NotificationsScreen>
      createState() =>
          _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  final StudentNotificationService
      _service =
      StudentNotificationService
          .instance;

  late Future<
      List<StudentNotification>>
      _notificationsFuture;

  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();

    _notificationsFuture =
        _loadNotifications();
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<List<StudentNotification>>
      _loadNotifications() async {
    final notifications =
        await _service
            .getNotifications();

    if (mounted) {
      setState(() {
        _unreadCount =
            notifications
                .where(
                  (notification) =>
                      !notification.isRead,
                )
                .length;
      });
    }

    return notifications;
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture =
          _loadNotifications();
    });

    await _notificationsFuture;
  }

  // ===========================================================================
  // OPEN NOTIFICATION
  // ===========================================================================

  Future<void> _openNotification(
    StudentNotification
        notification,
  ) async {
    if (!notification.isRead) {
      try {
        await _service
            .markAsRead(
          notification.id,
        );

        if (mounted) {
          setState(() {
            _unreadCount =
                _unreadCount > 0
                    ? _unreadCount - 1
                    : 0;
          });
        }
      } catch (e) {
        _showMessage(
          'Unable to update notification.',
        );
      }
    }

    final lectureId =
        notification.lectureId;

    if (lectureId != null &&
        lectureId.isNotEmpty &&
        widget.onLectureTap !=
            null) {
      await widget.onLectureTap!(
        lectureId,
      );
    }
  }

  // ===========================================================================
  // MARK ALL AS READ
  // ===========================================================================

  Future<void>
      _markAllAsRead() async {
    if (_unreadCount == 0) {
      return;
    }

    try {
      await _service
          .markAllAsRead();

      if (!mounted) {
        return;
      }

      setState(() {
        _unreadCount = 0;

        _notificationsFuture =
            _loadNotifications();
      });

      _showMessage(
        'All notifications marked as read.',
      );
    } catch (e) {
      _showMessage(
        'Unable to mark notifications as read.',
      );
    }
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ===========================================================================
  // DATE
  // ===========================================================================

  String _formatDate(
    DateTime date,
  ) {
    final local =
        date.toLocal();

    final now =
        DateTime.now();

    final difference =
        now.difference(local);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    final day =
        local.day
            .toString()
            .padLeft(
          2,
          '0',
        );

    final month =
        local.month
            .toString()
            .padLeft(
          2,
          '0',
        );

    final year =
        local.year.toString();

    return '$day/$month/$year';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Notifications',
            ),

            if (_unreadCount > 0) ...[
              const SizedBox(
                width: 10,
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      8,
                  vertical:
                      3,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      theme
                          .colorScheme
                          .error,
                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                ),
                child:
                    Text(
                  '$_unreadCount',
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              tooltip:
                  'Mark all as read',
              onPressed:
                  _markAllAsRead,
              icon:
                  const Icon(
                Icons
                    .done_all_rounded,
              ),
            ),

          IconButton(
            tooltip:
                'Refresh',
            onPressed:
                _refresh,
            icon:
                const Icon(
              Icons
                  .refresh_rounded,
            ),
          ),

          const SizedBox(
            width: 8,
          ),
        ],
      ),
      body:
          FutureBuilder<
              List<StudentNotification>>(
        future:
            _notificationsFuture,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot
                  .connectionState ==
              ConnectionState
                  .waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              onRetry:
                  _refresh,
              message:
                  snapshot.error
                      .toString(),
            );
          }

          final notifications =
              snapshot.data ??
                  [];

          if (notifications.isEmpty) {
            return const _EmptyView();
          }

          return RefreshIndicator(
            onRefresh:
                _refresh,
            child:
                ListView.separated(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets
                      .all(
                16,
              ),
              itemCount:
                  notifications.length,
              separatorBuilder:
                  (
                _,
                _,
              ) =>
                      const SizedBox(
                height: 10,
              ),
              itemBuilder:
                  (
                context,
                index,
              ) {
                final notification =
                    notifications[
                        index];

                return _NotificationCard(
                  notification:
                      notification,
                  formattedDate:
                      _formatDate(
                    notification
                        .createdAt,
                  ),
                  onTap: () =>
                      _openNotification(
                    notification,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// CARD
// ============================================================================

class _NotificationCard
    extends StatelessWidget {
  final StudentNotification
      notification;

  final String
      formattedDate;

  final VoidCallback
      onTap;

  const _NotificationCard({
    required this.notification,
    required this.formattedDate,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final isLecture =
        notification.type ==
            'new_lecture';

    return Material(
      color:
          Colors.transparent,
      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        onTap:
            onTap,
        child:
            Ink(
          decoration:
              BoxDecoration(
            color:
                notification.isRead
                    ? theme
                        .colorScheme
                        .surface
                    : theme
                        .colorScheme
                        .primary
                        .withValues(
                      alpha: 0.07,
                    ),
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border:
                Border.all(
              color:
                  notification.isRead
                      ? theme
                          .dividerColor
                      : theme
                          .colorScheme
                          .primary
                          .withValues(
                        alpha:
                            0.20,
                      ),
            ),
          ),
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child:
                Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(
                    color:
                        theme
                            .colorScheme
                            .primary
                            .withValues(
                      alpha:
                          0.10,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      Icon(
                    isLecture
                        ? Icons
                            .menu_book_rounded
                        : Icons
                            .notifications_rounded,
                    color:
                        theme
                            .colorScheme
                            .primary,
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Expanded(
                            child:
                                Text(
                              notification
                                  .title,
                              maxLines:
                                  2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    notification
                                            .isRead
                                        ? FontWeight
                                            .w600
                                        : FontWeight
                                            .w800,
                              ),
                            ),
                          ),

                          if (!notification
                              .isRead)
                            Container(
                              width: 9,
                              height: 9,
                              margin:
                                  const EdgeInsets
                                      .only(
                                left:
                                    8,
                                top:
                                    6,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    theme
                                        .colorScheme
                                        .primary,
                                shape:
                                    BoxShape
                                        .circle,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(
                        height: 7,
                      ),

                      Text(
                        notification.body,
                        maxLines:
                            4,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            TextStyle(
                          height:
                              1.4,
                          color:
                              theme
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                            alpha:
                                0.72,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Row(
                        children: [
                          Text(
                            formattedDate,
                            style:
                                theme
                                    .textTheme
                                    .bodySmall,
                          ),

                          if (notification
                                  .lectureId !=
                              null) ...[
                            const SizedBox(
                              width:
                                  10,
                            ),
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    8,
                                vertical:
                                    3,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    theme
                                        .colorScheme
                                        .primary
                                        .withValues(
                                  alpha:
                                      0.08,
                                ),
                                borderRadius:
                                    BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child:
                                  Text(
                                'Lecture',
                                style:
                                    TextStyle(
                                  fontSize:
                                      11,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  color:
                                      theme
                                          .colorScheme
                                          .primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      theme
                          .colorScheme
                          .onSurface
                          .withValues(
                    alpha:
                        0.45,
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

// ============================================================================
// EMPTY
// ============================================================================

class _EmptyView
    extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          32,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .notifications_none_rounded,
              size:
                  72,
              color:
                  theme
                      .colorScheme
                      .onSurface
                      .withValues(
                alpha:
                    0.35,
              ),
            ),
            const SizedBox(
              height:
                  18,
            ),
            const Text(
              'No notifications yet',
              style:
                  TextStyle(
                fontSize:
                    19,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              'You will find your updates and reminders here.',
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
                      0.60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _ErrorView
    extends StatelessWidget {
  final String message;

  final Future<void>
      Function() onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          32,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .cloud_off_rounded,
              size:
                  60,
              color:
                  theme
                      .colorScheme
                      .error,
            ),
            const SizedBox(
              height:
                  16,
            ),
            const Text(
              'Unable to load notifications',
              style:
                  TextStyle(
                fontSize:
                    18,
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
              maxLines:
                  5,
              overflow:
                  TextOverflow
                      .ellipsis,
            ),
            const SizedBox(
              height:
                  16,
            ),
            FilledButton.icon(
              onPressed:
                  onRetry,
              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
                  const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}