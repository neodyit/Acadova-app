import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'academic_profile_screen.dart';
import 'create_quiz_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class FacultyDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FacultyDashboardScreen({
    super.key,
    required this.userData,
  });

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  late Map<String, dynamic> _user;
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Active Quizzes, 1: Scheduled, 2: Campaign, 3: Submissions

  // Faculty Data
  Map<String, dynamic> _facultyStats = {
    'total_quizzes': 0,
    'active_quizzes': 0,
    'completed_quizzes': 0,
    'total_submissions': 0,
    'avg_accuracy': 0.0,
  };

  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _allocations = [];

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.userData);
    _fetchFacultyData();
  }

  Future<void> _fetchFacultyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch fresh user profile
      final profileResp = await ApiService.getProfile();
      if (profileResp['success'] == true && profileResp['data'] != null) {
        final freshData = profileResp['data'];
        final freshUser = (freshData is Map && freshData.containsKey('user'))
            ? freshData['user']
            : freshData;

        if (freshUser is Map<String, dynamic>) {
          _user = Map<String, dynamic>.from(freshUser);

          if (ApiService.isProfileIncomplete(_user)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => AcademicProfileScreen(userData: _user, isInitialSetup: true),
                  ),
                  (route) => false,
                );
              }
            });
            return;
          }
        }
      }

      // 2. Fetch Faculty Stats
      final stats = await ApiService.getFacultyStats();
      if (stats != null) {
        _facultyStats = stats;
      }

      // 3. Fetch Managed Quizzes
      final rawQuizzes = await ApiService.getQuizzes(status: 'all');
      final allQuizzes = List<Map<String, dynamic>>.from(rawQuizzes);

      final currentUserId = _user['id']?.toString();
      final currentName = (_user['name'] ?? _user['full_name'] ?? '').toString().trim().toLowerCase();

      _quizzes = allQuizzes.where((q) {
        final qUserId = q['user_id']?.toString() ?? q['created_by']?.toString();
        final qInstructor = (q['instructor'] ?? '').toString().trim().toLowerCase();

        if (currentUserId != null && qUserId != null) {
          return qUserId == currentUserId;
        }
        if (currentName.isNotEmpty && qInstructor.isNotEmpty) {
          return qInstructor == currentName;
        }
        return true;
      }).toList();

      // 4. Fetch Student Submissions
      final rawSubmissions = await ApiService.getFacultySubmissions();
      final allSubmissions = List<Map<String, dynamic>>.from(rawSubmissions);

      _submissions = allSubmissions.where((sub) {
        final quiz = sub['quiz'] is Map ? sub['quiz'] : {};
        if (quiz.isEmpty) return true;

        final qUserId = quiz['user_id']?.toString() ?? quiz['created_by']?.toString();
        final qInstructor = (quiz['instructor'] ?? '').toString().trim().toLowerCase();

        if (currentUserId != null && qUserId != null) {
          return qUserId == currentUserId;
        }
        if (currentName.isNotEmpty && qInstructor.isNotEmpty) {
          return qInstructor == currentName;
        }
        return true;
      }).toList();

      // 5. Fetch Faculty Allocations (Subjects & Sections)
      _allocations = await ApiService.getMyFacultyAllocations();
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Quiz Category Getters
  List<Map<String, dynamic>> get _activeQuizzes {
    return _quizzes.where((q) {
      final st = (q['status'] ?? '').toString().toLowerCase();
      final isActive = q['is_active'] == 1 || q['is_active'] == true;
      if (st == 'active' || st == 'published' || isActive) return true;
      if (st != 'scheduled' && st != 'completed' && st != 'draft' && st != 'archived') {
        return true;
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> get _scheduledQuizzes {
    return _quizzes.where((q) {
      final st = (q['status'] ?? '').toString().toLowerCase();
      if (st == 'scheduled') return true;
      if (q['scheduled_at'] != null || q['starts_at'] != null) {
        final rawDate = q['scheduled_at'] ?? q['starts_at'];
        final dt = DateTime.tryParse(rawDate.toString());
        if (dt != null && dt.isAfter(DateTime.now()) && st != 'completed') return true;
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> get _campaignQuizzes {
    return _quizzes.where((q) {
      final st = (q['status'] ?? '').toString().toLowerCase();
      return st == 'completed' || st == 'finished' || st == 'campaign' || st == 'archived';
    }).toList();
  }

  Future<void> _navigateToCreateQuizScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateQuizScreen(
          userData: _user,
          allocations: _allocations,
        ),
      ),
    );

    if (created == true && mounted) {
      _fetchFacultyData();
    }
  }

  void _showAddQuestionModal(Map<String, dynamic> quiz) {
    final questionController = TextEditingController();
    final opt1Controller = TextEditingController();
    final opt2Controller = TextEditingController();
    final opt3Controller = TextEditingController();
    final opt4Controller = TextEditingController();
    int correctIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_task_rounded, color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Add MCQ Question',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.mainText),
                                ),
                                Text(
                                  quiz['title'] ?? 'Quiz',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: questionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Question Text',
                          hintText: 'Enter question prompt...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Answer Options (Select the correct one):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mainText),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(4, (index) {
                        final controllers = [opt1Controller, opt2Controller, opt3Controller, opt4Controller];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Radio<int>(
                                value: index,
                                groupValue: correctIndex,
                                activeColor: AppTheme.primary,
                                onChanged: (val) {
                                  if (val != null) setModalState(() => correctIndex = val);
                                },
                              ),
                              Expanded(
                                child: TextField(
                                  controller: controllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Option ${index + 1}',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final qText = questionController.text.trim();
                            final opts = [
                              opt1Controller.text.trim(),
                              opt2Controller.text.trim(),
                              opt3Controller.text.trim(),
                              opt4Controller.text.trim(),
                            ];

                            if (qText.isEmpty || opts.any((o) => o.isEmpty)) {
                              CustomToast.show(context, message: 'Please fill in question and all 4 options', type: ToastType.error);
                              return;
                            }

                            final res = await ApiService.addQuestionToQuiz(
                              quizId: quiz['id'],
                              question: qText,
                              type: 'mcq',
                              options: opts,
                              correctOption: correctIndex,
                            );

                            if (mounted) {
                              if (res['success'] == true) {
                                if (modalCtx.mounted) Navigator.pop(modalCtx);
                                CustomToast.show(context, message: 'Question added successfully!', type: ToastType.success);
                                _fetchFacultyData();
                              } else {
                                CustomToast.show(context, message: res['message'] ?? 'Failed to add question', type: ToastType.error);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Save Question', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateAmPm(String? dateIso) {
    if (dateIso == null || dateIso.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(dateIso)?.toLocal();
    if (dt == null) return dateIso;
    
    final day = dt.day.toString().padLeft(2, '0');
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final year = dt.year;

    final hourNum = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final hour = hourNum.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return '$day $month $year, $hour:$minute $period';
  }

  Widget _buildFacultyDrawer(BuildContext context) {
    final String facultyName = _user['name'] ?? 'Faculty Member';
    final String email = _user['email'] ?? 'faculty@college.edu';
    final String facultyId = _user['faculty_id'] ?? 'FAC-ID';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: (_user['avatar'] != null && _user['avatar'].toString().isNotEmpty)
                      ? NetworkImage(_user['avatar'])
                      : null,
                  child: (_user['avatar'] == null || _user['avatar'].toString().isEmpty)
                      ? Text(
                          facultyName.isNotEmpty ? facultyName[0].toUpperCase() : 'F',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  facultyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'FACULTY • $facultyId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  title: 'My Dashboard',
                  isSelected: _selectedTab == 0,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 0);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.bolt_outlined,
                  activeIcon: Icons.bolt_rounded,
                  title: 'Active Quizzes',
                  badgeCount: _activeQuizzes.length,
                  isSelected: _selectedTab == 0,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 0);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today_rounded,
                  title: 'Scheduled Quizzes',
                  badgeCount: _scheduledQuizzes.length,
                  isSelected: _selectedTab == 1,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 1);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.campaign_outlined,
                  activeIcon: Icons.campaign_rounded,
                  title: 'Campaign & Completed',
                  badgeCount: _campaignQuizzes.length,
                  isSelected: _selectedTab == 2,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 2);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment_rounded,
                  title: 'Student Submissions',
                  badgeCount: _submissions.length,
                  isSelected: _selectedTab == 3,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 3);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                  child: Divider(color: AppTheme.border),
                ),
                _buildDrawerItem(
                  icon: Icons.add_circle_outline_rounded,
                  activeIcon: Icons.add_circle_rounded,
                  title: 'Create New Quiz',
                  iconColor: AppTheme.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCreateQuizScreen();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  title: 'My Profile',
                  onTap: () async {
                    Navigator.pop(context);
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfileScreen(userData: _user)),
                    );
                    if (updated != null && updated is Map<String, dynamic>) {
                      setState(() => _user = updated);
                    }
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer Logout Button
          const Divider(height: 1, color: AppTheme.border),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            onTap: () async {
              Navigator.pop(context);
              await ApiService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    int? badgeCount,
    Color? iconColor,
  }) {
    final color = isSelected ? AppTheme.primary : (iconColor ?? AppTheme.mainText);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(isSelected ? activeIcon : icon, color: color, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: (badgeCount != null && badgeCount > 0)
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.mainText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String facultyName = _user['name'] ?? 'Faculty Member';
    final String facultyId = _user['faculty_id'] ?? 'FAC-ID';
    final String department = _user['department'] ?? 'Faculty Department';

    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: _buildFacultyDrawer(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.mainText, size: 26),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Open Sidebar Menu',
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'My Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.mainText,
              ),
            ),
          ],
        ),
        actions: [
          // Notification Icon with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.mainText, size: 24),
                onPressed: () {
                  CustomToast.show(context, message: 'No new notifications', type: ToastType.info);
                },
                tooltip: 'Notifications',
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          // Profile Pic Avatar
          GestureDetector(
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen(userData: _user)),
              );
              if (updated != null && updated is Map<String, dynamic>) {
                setState(() => _user = updated);
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 4.0),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                backgroundImage: (_user['avatar'] != null && _user['avatar'].toString().isNotEmpty)
                    ? NetworkImage(_user['avatar'])
                    : null,
                child: (_user['avatar'] == null || _user['avatar'].toString().isEmpty)
                    ? Text(
                        facultyName.isNotEmpty ? facultyName[0].toUpperCase() : 'F',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _fetchFacultyData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Faculty Welcome Banner Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryDark, AppTheme.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                child: Text(
                                  facultyName.isNotEmpty ? facultyName[0].toUpperCase() : 'F',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back,',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                    Text(
                                      facultyName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: $facultyId  •  $department',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _navigateToCreateQuizScreen,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                              label: const Text('Create New Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryDark,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Quick Stats Metric Cards Overview
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Active',
                            count: _activeQuizzes.length,
                            icon: Icons.bolt_rounded,
                            color: AppTheme.success,
                            onTap: () => setState(() => _selectedTab = 0),
                            isSelected: _selectedTab == 0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Scheduled',
                            count: _scheduledQuizzes.length,
                            icon: Icons.calendar_today_rounded,
                            color: AppTheme.primary,
                            onTap: () => setState(() => _selectedTab = 1),
                            isSelected: _selectedTab == 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Campaign',
                            count: _campaignQuizzes.length,
                            icon: Icons.campaign_rounded,
                            color: Colors.purple,
                            onTap: () => setState(() => _selectedTab = 2),
                            isSelected: _selectedTab == 2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Navigation Filter Tab Buttons
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton(
                            index: 0,
                            title: 'Active Quizzes (${_activeQuizzes.length})',
                            icon: Icons.bolt_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            index: 1,
                            title: 'Scheduled (${_scheduledQuizzes.length})',
                            icon: Icons.calendar_today_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            index: 2,
                            title: 'Campaign (${_campaignQuizzes.length})',
                            icon: Icons.campaign_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            index: 3,
                            title: 'Submissions (${_submissions.length})',
                            icon: Icons.assignment_rounded,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tab Content Display
                    _buildSelectedTabContent(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppTheme.mainText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.mainText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildQuizList(
          quizzes: _activeQuizzes,
          emptyTitle: 'No Active Quizzes Right Now',
          emptySubtitle: 'Quizzes assigned by you that are currently active will appear here live.',
          badgeColor: AppTheme.success,
          badgeLabel: 'ACTIVE',
        );
      case 1:
        return _buildQuizList(
          quizzes: _scheduledQuizzes,
          emptyTitle: 'No Scheduled Quizzes',
          emptySubtitle: 'Quizzes scheduled for future start dates and times will appear here.',
          badgeColor: AppTheme.primary,
          badgeLabel: 'SCHEDULED',
        );
      case 2:
        return _buildQuizList(
          quizzes: _campaignQuizzes,
          emptyTitle: 'No Quiz Campaigns Found',
          emptySubtitle: 'Completed quiz campaigns and past assessments will be listed here.',
          badgeColor: Colors.purple,
          badgeLabel: 'CAMPAIGN',
        );
      case 3:
      default:
        return _buildSubmissionsTab();
    }
  }

  Widget _buildQuizList({
    required List<Map<String, dynamic>> quizzes,
    required String emptyTitle,
    required String emptySubtitle,
    required Color badgeColor,
    required String badgeLabel,
  }) {
    if (quizzes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              emptyTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.mainText),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _navigateToCreateQuizScreen,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create New Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: quizzes.map((quiz) {
        final int questionCount = quiz['questions_count'] ?? (quiz['questions'] is List ? (quiz['questions'] as List).length : 0);
        final String status = (quiz['status'] ?? badgeLabel).toString().toUpperCase();
        final String startStr = _formatDateAmPm(quiz['scheduled_at'] ?? quiz['starts_at']);
        final String endStr = _formatDateAmPm(quiz['ends_at']);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            quiz['subject'] ?? 'General Subject',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          quiz['title'] ?? 'Quiz Assessment',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mainText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '$questionCount Questions',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${quiz['duration_minutes'] ?? 15} mins',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
              if (startStr != 'N/A' || endStr != 'N/A') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Start: $startStr ${endStr != 'N/A' ? '• End: $endStr' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.mainText),
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showAddQuestionModal(quiz),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Question'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                    tooltip: 'Delete Quiz',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Quiz'),
                          content: Text('Are you sure you want to delete "${quiz['title']}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && quiz['id'] != null) {
                        final ok = await ApiService.deleteQuiz(quiz['id']);
                        if (ok && mounted) {
                          CustomToast.show(context, message: 'Quiz deleted', type: ToastType.info);
                          _fetchFacultyData();
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmissionsTab() {
    if (_submissions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No Student Submissions Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.mainText),
            ),
            const SizedBox(height: 6),
            const Text(
              'Student attempt results will appear here live as quizzes are completed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _submissions.map((sub) {
        final user = sub['user'] is Map ? sub['user'] : {};
        final quiz = sub['quiz'] is Map ? sub['quiz'] : {};
        final studentName = user['name'] ?? 'Student User';
        final rollNo = user['roll_number'] ?? 'N/A';
        final quizTitle = quiz['title'] ?? 'Quiz Assessment';
        final score = sub['score'] ?? 0;
        final totalQs = sub['total_questions'] ?? 1;
        final percentage = totalQs > 0 ? ((score / totalQs) * 100).round() : 0;
        final location = sub['location'] ?? 'Location Verified';
        final submittedAt = sub['submitted_at'] != null ? sub['submitted_at'].toString().split('T').first : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: percentage >= 50
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : AppTheme.error.withValues(alpha: 0.12),
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: percentage >= 50 ? AppTheme.primary : AppTheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.mainText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Roll: $rollNo  •  $quizTitle',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: percentage >= 50
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : AppTheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$score/$totalQs ($percentage%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: percentage >= 50 ? AppTheme.primary : AppTheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    submittedAt,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
