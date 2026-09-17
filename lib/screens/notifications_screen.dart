import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';

enum NotificationFilter { all, unread, quizzes, notices, alerts }

class NotificationsScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const NotificationsScreen({
    super.key,
    this.userData,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationFilter _selectedFilter = NotificationFilter.all;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(res['notifications'] ?? []);
          _unreadCount = res['unread_count'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    return _notifications.where((n) {
      final isUnread = n['is_read'] == false || n['is_read'] == 0 || n['isUnread'] == true;
      final type = (n['type'] ?? '').toString().toLowerCase();

      if (_selectedFilter == NotificationFilter.unread) {
        return isUnread;
      } else if (_selectedFilter == NotificationFilter.quizzes) {
        return type.contains('quiz') || type.contains('reminder') || type.contains('pending') || type.contains('scheduled');
      } else if (_selectedFilter == NotificationFilter.notices) {
        return type.contains('batch') || type.contains('notice') || type.contains('class') || type.contains('announcement') || type.contains('general');
      } else if (_selectedFilter == NotificationFilter.alerts) {
        return type.contains('alert') || type.contains('urgent') || type.contains('warning') || type.contains('emergency');
      }
      return true;
    }).toList();
  }

  Future<void> _markAllAsRead() async {
    final success = await ApiService.markAllNotificationsRead();
    if (success) {
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
          n['isUnread'] = false;
        }
        _unreadCount = 0;
      });
      if (mounted) {
        CustomToast.show(
          context,
          title: 'Notifications',
          message: 'All notifications marked as read.',
          type: ToastType.success,
        );
      }
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final id = notification['id'];
    if (id == null) return;
    final isUnread = notification['is_read'] == false || notification['is_read'] == 0 || notification['isUnread'] == true;

    if (isUnread) {
      setState(() {
        notification['is_read'] = true;
        notification['isUnread'] = false;
        if (_unreadCount > 0) _unreadCount--;
      });
      await ApiService.markNotificationRead(id);
    }
  }

  Future<void> _deleteNotification(dynamic id) async {
    setState(() {
      _notifications.removeWhere((n) => n['id'] == id);
    });
    await ApiService.deleteNotification(id);
  }

  void _handleNotificationTap(Map<String, dynamic> n) {
    _markAsRead(n);

    final actionType = (n['action_type'] ?? '').toString();
    final actionId = n['action_id'] ?? n['metadata']?['quiz_id'];

    if (actionType == 'open_quiz' && actionId != null) {
      final quizId = int.tryParse(actionId.toString());
      if (quizId != null) {
        // Navigate directly to quiz
        ApiService.getQuizDetails(quizId).then((quizData) {
          if (mounted && quizData != null) {
            CustomToast.show(
              context,
              title: n['title'] ?? 'Quiz Alert',
              message: 'Opening quiz details...',
              type: ToastType.info,
            );
          }
        });
      }
    }
  }

  String _formatTimeAgo(dynamic rawTime) {
    if (rawTime == null) return 'Just now';
    final str = rawTime.toString();
    if (str.contains('ago') || str.contains('Yesterday')) return str;

    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt == null) return str;

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _getCategoryColor(String type) {
    final t = type.toLowerCase().trim();
    if (t.contains('alert') || t.contains('urgent') || t.contains('emergency') || t.contains('warning')) {
      return const Color(0xFFE11D48); // Crimson Red
    }
    if (t.contains('batch') || t.contains('class') || t.contains('notice')) {
      return const Color(0xFF059669); // Emerald Green
    }
    if (t.contains('quiz') || t.contains('pending') || t.contains('reminder') || t.contains('scheduled') || t.contains('submitted') || t.contains('graded')) {
      return const Color(0xFF7C3AED); // Deep Purple
    }
    return const Color(0xFF2563EB); // Royal Blue (General Announcement)
  }

  List<Color> _getCategoryGradient(String type) {
    final t = type.toLowerCase().trim();
    if (t.contains('alert') || t.contains('urgent') || t.contains('emergency') || t.contains('warning')) {
      return [const Color(0xFFF43F5E), const Color(0xFFE11D48)]; // Red Crimson Gradient
    }
    if (t.contains('batch') || t.contains('class') || t.contains('notice')) {
      return [const Color(0xFF10B981), const Color(0xFF059669)]; // Emerald Gradient
    }
    if (t.contains('quiz') || t.contains('pending') || t.contains('reminder') || t.contains('scheduled') || t.contains('submitted') || t.contains('graded')) {
      return [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]; // Purple Gradient
    }
    return [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]; // Blue Gradient (Announcement)
  }

  IconData _getCategoryIcon(String type) {
    final t = type.toLowerCase().trim();
    if (t.contains('alert') || t.contains('urgent') || t.contains('emergency') || t.contains('warning')) {
      return Icons.error_outline_rounded;
    }
    if (t.contains('batch') || t.contains('class') || t.contains('notice')) {
      return Icons.school_rounded;
    }
    if (t.contains('pending') || t.contains('reminder')) {
      return Icons.timer_rounded;
    }
    if (t.contains('submitted') || t.contains('graded')) {
      return Icons.verified_rounded;
    }
    if (t.contains('quiz') || t.contains('scheduled')) {
      return Icons.quiz_rounded;
    }
    if (t.contains('general') || t.contains('announcement') || t.contains('campaign')) {
      return Icons.campaign_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  String _getCategoryBadgeLabel(String type) {
    final t = type.toLowerCase().trim();
    if (t.contains('alert') || t.contains('urgent') || t.contains('emergency')) return 'IMPORTANT ALERT';
    if (t.contains('batch') || t.contains('class') || t.contains('notice')) return 'CLASS NOTICE';
    if (t.contains('pending')) return 'PENDING REMINDER';
    if (t.contains('reminder')) return 'QUIZ REMINDER';
    if (t.contains('submitted')) return 'SUBMITTED';
    if (t.contains('graded')) return 'GRADED';
    if (t.contains('quiz') || t.contains('scheduled')) return 'QUIZ UPDATE';
    if (t.contains('general') || t.contains('announcement')) return 'ANNOUNCEMENT';
    return 'NOTIFICATION';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount new',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.mainText,
        actions: [
          if (_notifications.any((n) => n['is_read'] == false || n['is_read'] == 0 || n['isUnread'] == true))
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 16, color: AppTheme.primary),
              label: const Text(
                'Mark Read',
                style: TextStyle(color: AppTheme.primary, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: AppTheme.primary,
        child: Column(
          children: [
            // Filter Pills Row
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill(NotificationFilter.all, 'All (${_notifications.length})'),
                    const SizedBox(width: 8),
                    _buildFilterPill(NotificationFilter.unread, 'Unread ($_unreadCount)'),
                    const SizedBox(width: 8),
                    _buildFilterPill(NotificationFilter.quizzes, 'Quizzes'),
                    const SizedBox(width: 8),
                    _buildFilterPill(NotificationFilter.notices, 'Notices'),
                    const SizedBox(width: 8),
                    _buildFilterPill(NotificationFilter.alerts, 'Alerts'),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: AppTheme.border),

            // Notification Cards Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final n = filtered[index];
                            return _buildNotificationCard(n);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(NotificationFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.mainText,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final isUnread = n['is_read'] == false || n['is_read'] == 0 || n['isUnread'] == true;
    final type = (n['type'] ?? 'general').toString();
    final accentColor = _getCategoryColor(type);
    final gradientColors = _getCategoryGradient(type);
    final iconData = _getCategoryIcon(type);
    final badgeLabel = _getCategoryBadgeLabel(type);
    final timeStr = _formatTimeAgo(n['created_at'] ?? n['time']);
    final actionType = (n['action_type'] ?? '').toString();

    return Dismissible(
      key: Key(n['id']?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(n['id']),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isUnread ? accentColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? accentColor.withValues(alpha: 0.35) : Colors.grey.shade200,
            width: isUnread ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isUnread ? 0.05 : 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _handleNotificationTap(n),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Gradient Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      iconData,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),

                  // Content Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          n['title'] ?? 'Notification',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            color: AppTheme.mainText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n['body'] ?? '',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),

                        if (actionType == 'open_quiz') ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 32,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                label: const Text('Take Quiz Now', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _handleNotificationTap(n),
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 56,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.mainText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilter == NotificationFilter.unread
                  ? 'You are all caught up! No unread notifications.'
                  : 'You don\'t have any notifications right now. Scheduled quizzes, reminders, and alerts will appear here.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
