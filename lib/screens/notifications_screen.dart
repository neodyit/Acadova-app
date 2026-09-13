import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/custom_toast.dart';

enum NotificationFilter { all, unread, quizzes, announcements }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationFilter _selectedFilter = NotificationFilter.all;

  // Mock list of notifications
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'New Quiz Assigned: Algorithms Test 2',
      'body': 'Dr. Aman has posted a new quiz due today at 11:59 PM. Make sure to complete it on time.',
      'time': '10 mins ago',
      'type': 'quizzes',
      'isUnread': true,
      'color': const Color(0xFF6C5CE7),
      'icon': Icons.quiz_rounded,
    },
    {
      'id': '2',
      'title': 'Quiz Graded: Python Fundamentals',
      'body': 'You scored 92% (23/25) in Python Fundamentals. Tap to view detailed breakdown.',
      'time': '1 hour ago',
      'type': 'quizzes',
      'isUnread': true,
      'color': const Color(0xFF00B894),
      'icon': Icons.stars_rounded,
    },
    {
      'id': '3',
      'title': 'Tech Quiz League 2026 Registration',
      'body': 'Registrations are now open for the Annual Inter-College Tech Quiz. Win up to ₹50,000!',
      'time': '3 hours ago',
      'type': 'announcements',
      'isUnread': false,
      'color': const Color(0xFFE17055),
      'icon': Icons.campaign_rounded,
    },
    {
      'id': '4',
      'title': 'Schedule Alert: OS Midterms',
      'body': 'Operating Systems Scheduling Quiz has been rescheduled for tomorrow at 10:00 AM.',
      'time': 'Yesterday',
      'type': 'quizzes',
      'isUnread': false,
      'color': const Color(0xFF0984E3),
      'icon': Icons.event_note_rounded,
    },
    {
      'id': '5',
      'title': 'System Maintenance Update',
      'body': 'Acadova platform will undergo routine maintenance tonight from 02:00 AM to 03:00 AM.',
      'time': '2 days ago',
      'type': 'announcements',
      'isUnread': false,
      'color': const Color(0xFF636E72),
      'icon': Icons.build_circle_rounded,
    },
  ];

  List<Map<String, dynamic>> get _filteredNotifications {
    return _notifications.where((n) {
      if (_selectedFilter == NotificationFilter.unread) {
        return n['isUnread'] == true;
      } else if (_selectedFilter == NotificationFilter.quizzes) {
        return n['type'] == 'quizzes';
      } else if (_selectedFilter == NotificationFilter.announcements) {
        return n['type'] == 'announcements';
      }
      return true;
    }).toList();
  }

  void _markAllAsRead() {
    setState(() {
      for (var n in _notifications) {
        n['isUnread'] = false;
      }
    });
    CustomToast.show(
      context,
      title: 'Notifications',
      message: 'All notifications marked as read.',
      type: ToastType.success,
    );
  }

  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n['id'] == id);
    });
    CustomToast.show(
      context,
      title: 'Deleted',
      message: 'Notification removed.',
      type: ToastType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['isUnread'] == true).length;

    return Scaffold(
      backgroundColor: AppTheme.background,

      // App Bar
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        foregroundColor: AppTheme.mainText,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.mainText),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppTheme.primary),
              label: const Text(
                'Mark read',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills Section
            Container(
              color: AppTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      filter: NotificationFilter.all,
                      badgeCount: _notifications.length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Unread',
                      filter: NotificationFilter.unread,
                      badgeCount: unreadCount,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Quizzes & Grades',
                      filter: NotificationFilter.quizzes,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Announcements',
                      filter: NotificationFilter.announcements,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: AppTheme.border),

            // Notifications List
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 600));
                  setState(() {});
                },
                child: _filteredNotifications.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildEmptyState(),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredNotifications.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notification = _filteredNotifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter Chip Widget
  Widget _buildFilterChip({
    required String label,
    required NotificationFilter filter,
    int? badgeCount,
  }) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.mainText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF6C5CE7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Notification Card Item
  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isUnread = notification['isUnread'] == true;
    final Color iconColor = notification['color'] as Color;

    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _deleteNotification(notification['id']),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            notification['isUnread'] = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnread ? Colors.white : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
                  : Colors.grey.shade200,
              width: isUnread ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (isUnread)
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification['icon'] as IconData,
                  color: iconColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              // Title, Body, Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF2D3436),
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C5CE7),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      notification['body'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          notification['time'],
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 54,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No notifications match your selected filter.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
