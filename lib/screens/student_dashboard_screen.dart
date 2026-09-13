import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/location_permission_banner.dart';
import 'academic_profile_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'quiz_attempt_screen.dart';
import 'quizzes_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StudentDashboardScreen({
    super.key,
    required this.userData,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _activeNavIndex = 0;

  late Map<String, dynamic> _userData;
  List<Map<String, dynamic>> _activeQuizzes = [];
  List<Map<String, dynamic>> _upcomingQuizzes = [];
  List<Map<String, dynamic>> _recentSubmissions = [];
  Set<int> _attemptedQuizIds = {};
  Map<int, Map<String, dynamic>> _attemptMap = {};
  List<Map<String, dynamic>> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
    _fetchBackendData();
  }

  Future<void> _fetchBackendData() async {
    final profileResp = await ApiService.getProfile();
    final active = await ApiService.getQuizzes(status: 'active');
    final upcoming = await ApiService.getQuizzes(status: 'upcoming');
    final attempts = await ApiService.getUserAttempts();
    final campaignsData = await ApiService.getCampaigns(status: 'active');

    if (mounted) {
      if (profileResp['success'] == true && profileResp['data'] != null) {
        final freshData = profileResp['data'];
        final freshUser = (freshData is Map && freshData.containsKey('user'))
            ? freshData['user']
            : freshData;
        if (freshUser is Map<String, dynamic>) {
          _userData = Map<String, dynamic>.from(freshUser);

          final isStudent = (_userData['role'] ?? 'student').toString().toLowerCase() == 'student';
          final isProfileIncomplete = isStudent && (
            _userData['phone'] == null || _userData['phone'].toString().trim().isEmpty ||
            _userData['roll_number'] == null || _userData['roll_number'].toString().trim().isEmpty ||
            _userData['university_id'] == null ||
            _userData['college_id'] == null ||
            _userData['department_id'] == null ||
            _userData['course_id'] == null ||
            _userData['branch_id'] == null ||
            _userData['section_id'] == null ||
            _userData['subsection_id'] == null
          );

          if (isProfileIncomplete) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => AcademicProfileScreen(userData: _userData, isInitialSetup: true),
                  ),
                  (route) => false,
                );
              }
            });
            return;
          }
        }
      }
      final now = DateTime.now();
      setState(() {
        _campaigns = campaignsData.map((c) {
          List<Color> gradient = [AppTheme.primary, AppTheme.primaryLight];
          final colorKey = c['banner_color']?.toString().toLowerCase() ?? 'amber';
          if (colorKey == 'orange' || colorKey == 'coral' || colorKey == 'rust') {
            gradient = [const Color(0xFFC2410C), const Color(0xFFEA580C)];
          } else if (colorKey == 'teal' || colorKey == 'emerald' || colorKey == 'green') {
            gradient = [const Color(0xFF15803D), const Color(0xFF22C55E)];
          } else if (colorKey == 'blue' || colorKey == 'ocean') {
            gradient = [const Color(0xFF0369A1), const Color(0xFF0284C7)];
          } else if (colorKey == 'brown' || colorKey == 'dark') {
            gradient = [AppTheme.primaryDark, AppTheme.primary];
          } else {
            gradient = [AppTheme.primary, AppTheme.primaryLight];
          }

          DateTime? endsAt = ApiService.parseDateTime(c['ends_at']);

          return {
            'id': c['id'],
            'title': c['title'] ?? 'Announcement',
            'description': c['description'] ?? '',
            'badge': c['badge'] ?? 'Notice',
            'linkUrl': c['link_url'],
            'endsAt': endsAt,
            'gradient': gradient,
          };
        }).where((c) {
          final endsAt = c['endsAt'] as DateTime?;
          return endsAt == null || endsAt.isAfter(now);
        }).toList();

        _attemptedQuizIds = attempts.map((att) => (att['quiz_id'] as num).toInt()).toSet();
        _attemptMap = {};
        for (var att in attempts) {
          final qId = (att['quiz_id'] as num).toInt();
          _attemptMap[qId] = att;
        }

        final List<Map<String, dynamic>> allAvailableQuizzes = [...active, ...upcoming];
        final Set<int> processedQuizIds = {};

        _activeQuizzes = [];
        _upcomingQuizzes = [];

        for (var q in allAvailableQuizzes) {
          final int qId = q['id'] as int;
          if (processedQuizIds.contains(qId)) continue;
          processedQuizIds.add(qId);

          DateTime? startsAt = ApiService.parseDateTime(q['starts_at'] ?? q['scheduled_at']);
          DateTime? endsAt = ApiService.parseDateTime(q['ends_at']);

          final bool isAttempted = _attemptedQuizIds.contains(qId);
          final att = _attemptMap[qId];

          // Determine quiz time state
          final bool isBeforeStart = startsAt != null && now.isBefore(startsAt);
          final bool isAfterEnd = endsAt != null && now.isAfter(endsAt);
          final bool isLiveNow = (startsAt == null || !isBeforeStart) && !isAfterEnd;

          String dateFormatted = 'Scheduled Soon';
          if (startsAt != null) {
            final hour = startsAt.hour % 12 == 0 ? 12 : startsAt.hour % 12;
            final ampm = startsAt.hour >= 12 ? 'PM' : 'AM';
            final min = startsAt.minute.toString().padLeft(2, '0');
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            dateFormatted = '${startsAt.day} ${months[startsAt.month - 1]}, $hour:$min $ampm';
          }

          final quizItem = {
            'id': qId,
            'title': q['title'],
            'subject': q['subject'] ?? 'General',
            'instructor': q['instructor'] ?? 'Faculty',
            'description': q['description'] ?? 'No description provided.',
            'questions': q['questions_count'] ?? 0,
            'duration': '${q['duration_minutes'] ?? 15} mins',
            'durationMinutes': q['duration_minutes'] ?? 15,
            'due': isLiveNow ? 'Available Now' : (isBeforeStart ? 'Starts $dateFormatted' : 'Ended'),
            'isAttempted': isAttempted,
            'attemptData': att,
            'startsAt': startsAt,
            'endsAt': endsAt,
            'isBeforeStart': isBeforeStart,
            'isAfterEnd': isAfterEnd,
            'isLiveNow': isLiveNow,
            'color': isAfterEnd && !isAttempted
                ? const Color(0xFFFF7675)
                : (isLiveNow ? const Color(0xFF6C5CE7) : const Color(0xFF0984E3)),
          };

          if (isAttempted || isLiveNow || isAfterEnd) {
            _activeQuizzes.add(quizItem);
          } else {
            _upcomingQuizzes.add({
              'id': qId,
              'title': q['title'],
              'date': dateFormatted,
              'questions': q['questions_count'] ?? 0,
              'duration': '${q['duration_minutes'] ?? 15} mins',
              'startsAt': startsAt,
              'endsAt': endsAt,
            });
          }
        }

        _recentSubmissions = attempts.map((att) {
          final quiz = att['quiz'] ?? {};
          final score = att['score'] ?? 0;
          final total = att['total_questions'] ?? 1;
          final pct = total > 0 ? ((score / total) * 100).round() : 0;
          final passed = pct >= 50;

          String dateFormatted = 'Submitted';
          if (att['created_at'] != null || att['submitted_at'] != null) {
            try {
              final d = DateTime.parse(att['submitted_at'] ?? att['created_at']);
              dateFormatted = '${d.day}/${d.month}/${d.year}';
            } catch (_) {}
          }

          return {
            'title': quiz['title'] ?? 'Quiz Attempt',
            'score': '$pct%',
            'marks': '$score / $total',
            'date': dateFormatted,
            'status': passed ? 'Passed' : 'Needs Review',
            'color': passed ? const Color(0xFF00B894) : const Color(0xFFFF7675),
          };
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = _userData['name'] ?? 'Student';
    final String email = _userData['email'] ?? '';
    final String rollNumber = _userData['roll_number'] ?? _userData['faculty_id'] ?? 'N/A';
    final String? avatarUrl = ApiService.formatMediaUrl(_userData['avatar']?.toString());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,

      // App Bar Navigation Header
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.mainText),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                height: 28,
                width: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.school, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'My Dashboard',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.mainText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppTheme.mainText),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () async {
                final updated = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userData: _userData),
                  ),
                );
                if (updated != null && updated is Map<String, dynamic>) {
                  setState(() => _userData = Map<String, dynamic>.from(updated));
                }
              },
              child: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          color: Color(0xFF6C5CE7),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),

      // Side Navigation Drawer
      drawer: Drawer(
        backgroundColor: AppTheme.background,
        child: Column(
          children: [
            // Drawer Header
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final updated = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userData: _userData),
                  ),
                );
                if (updated != null && updated is Map<String, dynamic>) {
                  setState(() => _userData = Map<String, dynamic>.from(updated));
                }
              },
              child: UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
                accountName: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                accountEmail: Text(
                  '$email  •  Roll: $rollNumber',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ),

            // Navigation Items
            _buildDrawerTile(
              index: 0,
              icon: Icons.dashboard_rounded,
              title: 'Dashboard',
            ),
            _buildDrawerTile(
              index: 1,
              icon: Icons.quiz_rounded,
              title: 'Active Quizzes',
              badgeText: '${_activeQuizzes.length}',
            ),
            _buildDrawerTile(
              index: 2,
              icon: Icons.event_note_rounded,
              title: 'Upcoming Quizzes',
            ),
            _buildDrawerTile(
              index: 3,
              icon: Icons.assignment_turned_in_rounded,
              title: 'Recent Submissions',
            ),
            _buildDrawerTile(
              index: 4,
              icon: Icons.campaign_rounded,
              title: 'Campaigns & Events',
            ),

            const Divider(color: AppTheme.border, height: 24, indent: 16, endIndent: 16),

            _buildDrawerTile(
              index: 5,
              icon: Icons.person_outline_rounded,
              title: 'Profile Settings',
            ),

            const Spacer(),

            // Logout Option
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppTheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ApiService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      // Main Dashboard Body
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF6C5CE7),
          onRefresh: () async {
            await _fetchBackendData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome Banner
              _buildStudentHeader(name, rollNumber),

              const SizedBox(height: 24),

              // 2. Active Quizzes Section
              _buildSectionHeader(
                title: 'Active Quizzes',
                badgeCount: _activeQuizzes.length,
                actionText: 'View All',
                onActionTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const QuizzesScreen(initialTabIndex: 0),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _activeQuizzes.isEmpty
                  ? _buildEmptySectionCard(
                      icon: Icons.assignment_rounded,
                      title: 'No Active Quizzes Available',
                      message: 'Check back later or pull down to refresh.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _activeQuizzes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final quiz = _activeQuizzes[index];
                        return _buildActiveQuizCard(quiz);
                      },
                    ),

              const SizedBox(height: 28),

              // 3. Campaigns & Announcements Carousel / Cards
              _buildSectionHeader(
                title: 'Campaigns & Announcements',
                actionText: 'Explore',
                onActionTap: () {},
              ),
              const SizedBox(height: 12),
              _campaigns.isEmpty
                  ? _buildEmptySectionCard(
                      icon: Icons.campaign_rounded,
                      title: 'No Active Announcements',
                      message: 'There are currently no active promotional events or notices.',
                    )
                  : SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _campaigns.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final campaign = _campaigns[index];
                          return _buildCampaignCard(campaign);
                        },
                      ),
                    ),

              const SizedBox(height: 28),

              // 4. Upcoming Quizzes Section
              _buildSectionHeader(
                title: 'Upcoming Quizzes',
                actionText: 'Calendar',
                onActionTap: () {},
              ),
              const SizedBox(height: 12),
              _upcomingQuizzes.isEmpty
                  ? _buildEmptySectionCard(
                      icon: Icons.event_busy_rounded,
                      title: 'No Upcoming Quizzes',
                      message: 'There are no upcoming scheduled tests at this moment.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _upcomingQuizzes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final quiz = _upcomingQuizzes[index];
                        return _buildUpcomingQuizTile(quiz);
                      },
                    ),

              const SizedBox(height: 28),

              // 5. Recent Submissions Section
              _buildSectionHeader(
                title: 'Recent Submissions',
                actionText: 'History',
                onActionTap: () {},
              ),
              const SizedBox(height: 12),
              _recentSubmissions.isEmpty
                  ? _buildEmptySectionCard(
                      icon: Icons.history_edu_rounded,
                      title: 'No Submissions Yet',
                      message: 'Complete active quizzes to see your score records here.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentSubmissions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final submission = _recentSubmissions[index];
                        return _buildSubmissionTile(submission);
                      },
                    ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  // Drawer Item Helper
  Widget _buildDrawerTile({
    required int index,
    required IconData icon,
    required String title,
    String? badgeText,
  }) {
    final isSelected = _activeNavIndex == index;
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primary : AppTheme.textMuted,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.mainText,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: (badgeText != null && badgeText.isNotEmpty && badgeText != '0')
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: () async {
        setState(() {
          _activeNavIndex = index;
        });
        Navigator.pop(context);

        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const QuizzesScreen(initialTabIndex: 0),
            ),
          );
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const QuizzesScreen(initialTabIndex: 1),
            ),
          );
        } else if (index == 3) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const QuizzesScreen(initialTabIndex: 2),
            ),
          );
        } else if (index == 5) {
          final updated = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userData: _userData),
            ),
          );
          if (updated != null && updated is Map<String, dynamic>) {
            setState(() => _userData = Map<String, dynamic>.from(updated));
          }
        }
      },
    );
  }

  // Premium Modern Student Header Banner
  Widget _buildStudentHeader(String name, String rollNumber) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Decorative Glassmorphic Shapes
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'ACADOVA PORTAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rollNumber.isNotEmpty && rollNumber != 'N/A')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'ID: $rollNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Welcome Greeting
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Live Active Quiz Pill Info Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _activeQuizzes.isNotEmpty ? Icons.play_arrow_rounded : Icons.check_rounded,
                          color: const Color(0xFF6C5CE7),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _activeQuizzes.isNotEmpty
                              ? '${_activeQuizzes.length} Active quiz available to attempt'
                              : 'All assigned quizzes are up to date!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section Header Builder
  Widget _buildSectionHeader({
    required String title,
    int? badgeCount,
    required String actionText,
    required VoidCallback onActionTap,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.mainText,
          ),
        ),
        if (badgeCount != null && badgeCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$badgeCount',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: onActionTap,
          child: Text(
            actionText,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySectionCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF6C5CE7), size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _showQuizDetailsModal(Map<String, dynamic> quiz) {
    final bool isAttempted = quiz['isAttempted'] == true;
    final att = quiz['attemptData'];

    int score = 0;
    int totalQs = quiz['questions'] ?? 0;
    int percentage = 0;
    if (att != null) {
      score = att['score'] ?? 0;
      totalQs = att['total_questions'] ?? totalQs;
      percentage = totalQs > 0 ? ((score / totalQs) * 100).round() : 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottomsheet handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title and Category Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            quiz['subject'] ?? 'General',
                            style: const TextStyle(
                              color: Color(0xFF6C5CE7),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          quiz['title'] ?? 'Quiz',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAttempted
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAttempted ? Icons.check_circle_rounded : Icons.sensors_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAttempted ? 'Completed' : 'Available',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Faculty info
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Instructor: ${quiz['instructor']}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quiz Details & Instructions',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mainText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quiz['description'] ?? 'No special instructions provided for this quiz.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Metrics Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Total Questions',
                      value: '${quiz['questions']} Qs',
                      color: AppTheme.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: quiz['duration'] ?? '15 mins',
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Attempt Result Card (If Attempted)
              if (isAttempted) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: percentage >= 50
                          ? [AppTheme.primary, AppTheme.primaryLight]
                          : [AppTheme.error, const Color(0xFFDC2626)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (percentage >= 50 ? AppTheme.primary : AppTheme.error).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          percentage >= 50 ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quiz Already Attempted',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Score: $score / $totalQs ($percentage%)',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Bottom Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (isAttempted) {
                      Navigator.pop(sheetContext);
                      CustomToast.show(
                        context,
                        title: 'Already Attempted',
                        message: 'You have already submitted your response for this quiz.',
                        type: ToastType.info,
                      );
                      return;
                    }

                    if (quiz['isAfterEnd'] == true) {
                      Navigator.pop(sheetContext);
                      CustomToast.show(
                        context,
                        title: 'Quiz Expired / Missed',
                        message: 'This quiz has ended and can no longer be attempted.',
                        type: ToastType.error,
                        customIcon: Icons.timer_off_rounded,
                      );
                      return;
                    }

                    if (quiz['isBeforeStart'] == true) {
                      Navigator.pop(sheetContext);
                      CustomToast.show(
                        context,
                        title: 'Quiz Not Started',
                        message: 'This quiz is scheduled to start at ${quiz['due']}.',
                        type: ToastType.warning,
                        customIcon: Icons.schedule_rounded,
                      );
                      return;
                    }

                    Navigator.pop(sheetContext); // Close modal sheet

                    if (!mounted) return;

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    );

                    List<Map<String, dynamic>> questions = [];
                    if (quiz['id'] != null) {
                      final quizDetails = await ApiService.getQuizDetails(quiz['id']);
                      if (quizDetails != null && quizDetails['questions'] is List && (quizDetails['questions'] as List).isNotEmpty) {
                        questions = List<Map<String, dynamic>>.from(
                          (quizDetails['questions'] as List).map((q) {
                            List<String> parsedOptions = [];
                            if (q['options'] is List) {
                              parsedOptions = List<String>.from((q['options'] as List).map((e) => e?.toString() ?? ''));
                            } else if (q['options'] is String && (q['options'] as String).isNotEmpty) {
                              try {
                                final decoded = jsonDecode(q['options']);
                                if (decoded is List) {
                                  parsedOptions = List<String>.from(decoded.map((e) => e?.toString() ?? ''));
                                }
                              } catch (_) {}
                            }
                            return {
                              'id': q['id'],
                              'question': q['question'] ?? '',
                              'type': q['type'] ?? 'single',
                              'options': parsedOptions,
                              'correct_option': q['correct_option'],
                            };
                          }),
                        );
                      }
                    }

                    if (!mounted) return;
                    Navigator.of(context, rootNavigator: true).pop(); // Close loader

                    if (questions.isEmpty) {
                      CustomToast.show(
                        context,
                        title: 'No Questions',
                        message: 'This quiz does not have any questions added yet.',
                        type: ToastType.warning,
                      );
                      return;
                    }

                    if (!mounted) return;

                    final locationData = await LocationPermissionBannerDialog.requestAndFetchLocation(
                      context,
                      quiz['title'] ?? 'Quiz',
                    );

                    if (locationData == null) {
                      return; // User cancelled or denied location permission
                    }

                    if (!mounted) return;

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuizAttemptScreen(
                          quizId: quiz['id'],
                          quizTitle: quiz['title'],
                          subject: quiz['subject'],
                          durationMinutes: quiz['durationMinutes'] ?? 15,
                          questions: questions,
                          location: locationData['location'],
                          latitude: locationData['latitude'],
                          longitude: locationData['longitude'],
                        ),
                      ),
                    ).then((_) {
                      if (mounted) _fetchBackendData();
                    });
                  },
                  icon: Icon(isAttempted ? Icons.check_circle_rounded : Icons.play_arrow_rounded),
                  label: Text(
                    isAttempted ? 'Already Attempted' : 'Start Attempt Now',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAttempted ? AppTheme.success : AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  // Active Quiz Card Widget - Premium Redesign
  Widget _buildActiveQuizCard(Map<String, dynamic> quiz) {
    final bool isAttempted = quiz['isAttempted'] == true;

    return InkWell(
      onTap: () => _showQuizDetailsModal(quiz),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAttempted
                ? AppTheme.success.withValues(alpha: 0.3)
                : AppTheme.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isAttempted
                  ? AppTheme.success.withValues(alpha: 0.08)
                  : AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Subject Chip & Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    quiz['subject'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isAttempted
                        ? AppTheme.success.withValues(alpha: 0.12)
                        : (quiz['isAfterEnd'] == true
                            ? AppTheme.error.withValues(alpha: 0.12)
                            : (quiz['isBeforeStart'] == true
                                ? AppTheme.info.withValues(alpha: 0.12)
                                : AppTheme.primary.withValues(alpha: 0.12))),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAttempted
                            ? Icons.check_circle_rounded
                            : (quiz['isAfterEnd'] == true
                                ? Icons.cancel_rounded
                                : (quiz['isBeforeStart'] == true ? Icons.schedule_rounded : Icons.sensors_rounded)),
                        size: 13,
                        color: isAttempted
                            ? AppTheme.success
                            : (quiz['isAfterEnd'] == true
                                ? AppTheme.error
                                : (quiz['isBeforeStart'] == true ? AppTheme.info : AppTheme.primary)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAttempted
                            ? 'Completed'
                            : (quiz['isAfterEnd'] == true
                                ? 'Missed'
                                : (quiz['isBeforeStart'] == true ? 'Scheduled' : 'Live Now')),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isAttempted
                              ? AppTheme.success
                              : (quiz['isAfterEnd'] == true
                                  ? AppTheme.error
                                  : (quiz['isBeforeStart'] == true ? AppTheme.info : AppTheme.primary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              quiz['title'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
                letterSpacing: -0.3,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // Instructor Row
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 16, color: Color(0xFF636E72)),
                const SizedBox(width: 6),
                Text(
                  'Instructor: ${quiz['instructor']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF636E72),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Bottom Info Bar & Attempt Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.quiz_outlined, size: 15, color: Color(0xFF2D3436)),
                      const SizedBox(width: 4),
                      Text(
                        '${quiz['questions']} Qs',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.timer_outlined, size: 15, color: Color(0xFF2D3436)),
                      const SizedBox(width: 4),
                      Text(
                        quiz['duration'],
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showQuizDetailsModal(quiz),
                  icon: Icon(
                    isAttempted
                        ? Icons.check_circle_rounded
                        : (quiz['isAfterEnd'] == true
                            ? Icons.cancel_rounded
                            : (quiz['isBeforeStart'] == true ? Icons.schedule_rounded : Icons.play_arrow_rounded)),
                    size: 16,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAttempted
                        ? AppTheme.success
                        : (quiz['isAfterEnd'] == true
                            ? AppTheme.error
                            : (quiz['isBeforeStart'] == true ? AppTheme.info : AppTheme.primary)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: (isAttempted
                            ? AppTheme.success
                            : (quiz['isAfterEnd'] == true
                                ? AppTheme.error
                                : (quiz['isBeforeStart'] == true ? AppTheme.info : AppTheme.primary)))
                        .withValues(alpha: 0.3),
                  ),
                  label: Text(
                    isAttempted
                        ? 'Done'
                        : (quiz['isAfterEnd'] == true
                            ? 'Missed'
                            : (quiz['isBeforeStart'] == true ? 'Scheduled' : 'Attempt')),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Open Campaign Action Link
  Future<void> _openCampaignUrl(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty || rawUrl.trim().toLowerCase() == 'null') {
      if (mounted) {
        CustomToast.show(context, message: 'No link provided for this campaign', type: ToastType.info);
      }
      return;
    }

    var formattedUrl = rawUrl.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final uri = Uri.tryParse(formattedUrl);
    if (uri == null || uri.host.isEmpty) {
      if (mounted) {
        CustomToast.show(context, message: 'Invalid URL format: $rawUrl', type: ToastType.warning);
      }
      return;
    }

    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && mounted) {
        CustomToast.show(context, message: 'Could not open link ($formattedUrl)', type: ToastType.warning);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, message: 'Unable to open link in browser', type: ToastType.warning);
      }
    }
  }

  // Format End Time Helper
  String _formatEndTime(DateTime endsAt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[endsAt.month - 1];
    final hour = endsAt.hour > 12 ? endsAt.hour - 12 : (endsAt.hour == 0 ? 12 : endsAt.hour);
    final period = endsAt.hour >= 12 ? 'PM' : 'AM';
    final minute = endsAt.minute.toString().padLeft(2, '0');
    return '${endsAt.day} $month ${endsAt.year}, $hour:$minute $period';
  }

  // Show Campaign Modal Bottom Sheet
  void _showCampaignModal(Map<String, dynamic> campaign) {
    final String? linkUrl = campaign['linkUrl'];
    final DateTime? endsAt = campaign['endsAt'];
    final bool hasValidLink = linkUrl != null &&
        linkUrl.trim().isNotEmpty &&
        linkUrl.trim().toLowerCase() != 'null';
    final List<Color> gradient = campaign['gradient'] ?? [AppTheme.primary, AppTheme.primaryLight];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: gradient[0].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      campaign['badge'] ?? 'Notice',
                      style: TextStyle(
                        color: gradient[0],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (endsAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 13, color: Colors.amber.shade900),
                          const SizedBox(width: 4),
                          Text(
                            'Ends: ${_formatEndTime(endsAt)}',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                campaign['title'] ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                campaign['description'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              if (hasValidLink) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openCampaignUrl(linkUrl);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gradient[0],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Open Action Link',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Campaign Banner Card - Premium Gradient Card
  Widget _buildCampaignCard(Map<String, dynamic> campaign) {
    final String? linkUrl = campaign['linkUrl'];
    final DateTime? endsAt = campaign['endsAt'];
    final bool hasValidLink = linkUrl != null &&
        linkUrl.trim().isNotEmpty &&
        linkUrl.trim().toLowerCase() != 'null';

    return GestureDetector(
      onTap: () => _showCampaignModal(campaign),
      child: Container(
        width: 270,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: campaign['gradient'],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (campaign['gradient'][0] as Color).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    campaign['badge'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (hasValidLink)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              campaign['title'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              campaign['description'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
            if (endsAt != null) ...[
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: Colors.white.withValues(alpha: 0.9), size: 13),
                  const SizedBox(width: 5),
                  Text(
                    'Ends ${_formatEndTime(endsAt)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Upcoming Quiz Tile
  Widget _buildUpcomingQuizTile(Map<String, dynamic> quiz) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_note_rounded, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz['title'] ?? 'Upcoming Quiz',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.mainText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      quiz['date'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${quiz['questions']} Questions  •  ${quiz['duration']}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Submission History Tile
  Widget _buildSubmissionTile(Map<String, dynamic> submission) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (submission['color'] as Color).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: submission['color']),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted on ${submission['date']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                submission['score'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: submission['color'],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                submission['marks'],
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
