import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/location_permission_banner.dart';
import 'quiz_attempt_screen.dart';

enum QuizTabFilter { active, upcoming, completed }

class QuizzesScreen extends StatefulWidget {
  final int initialTabIndex;

  const QuizzesScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Dynamic dataset for quizzes
  List<Map<String, dynamic>> _allQuizzes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _fetchQuizzesFromBackend();
  }

  Future<void> _fetchQuizzesFromBackend() async {
    final activeList = await ApiService.getQuizzes(status: 'active');
    final upcomingList = await ApiService.getQuizzes(status: 'upcoming');
    final completedList = await ApiService.getQuizzes(status: 'completed');
    final attempts = await ApiService.getUserAttempts();

    final Map<int, Map<String, dynamic>> attemptMap = {};
    for (var att in attempts) {
      if (att['quiz_id'] != null) {
        attemptMap[(att['quiz_id'] as num).toInt()] = att;
      }
    }

    if (mounted) {
      setState(() {
        final List<Map<String, dynamic>> mappedList = [];

        // Active quizzes
        for (var q in activeList) {
          final int qId = q['id'];
          final bool isAttempted = attemptMap.containsKey(qId);
          final att = attemptMap[qId];

          if (isAttempted) {
            final score = att?['score'] ?? 0;
            final total = att?['total_questions'] ?? q['questions_count'] ?? 1;
            final pct = total > 0 ? ((score / total) * 100).round() : 0;
            final passed = pct >= 50;

            mappedList.add({
              'id': qId,
              'title': q['title'],
              'subject': q['subject'] ?? 'General',
              'category': 'completed',
              'description': q['description'] ?? 'No description provided.',
              'questions': total,
              'duration': '${q['duration_minutes'] ?? 15} mins',
              'score': '$pct%',
              'marks': '$score / $total',
              'date': 'Completed',
              'status': passed ? 'Passed' : 'Needs Review',
              'instructor': q['instructor'] ?? 'Faculty',
              'isAttempted': true,
              'attemptData': att,
              'color': passed ? const Color(0xFF00B894) : const Color(0xFFFF7675),
              'icon': Icons.task_alt_rounded,
            });
          } else {
            mappedList.add({
              'id': qId,
              'title': q['title'],
              'subject': q['subject'] ?? 'General',
              'category': 'active',
              'description': q['description'] ?? 'No description provided.',
              'questions': q['questions_count'] ?? 0,
              'duration': '${q['duration_minutes'] ?? 15} mins',
              'durationMinutes': q['duration_minutes'] ?? 15,
              'due': 'Available Now',
              'instructor': q['instructor'] ?? 'Faculty',
              'isAttempted': false,
              'color': AppTheme.primary,
              'icon': Icons.account_tree_rounded,
            });
          }
        }

        // Upcoming quizzes
        for (var q in upcomingList) {
          String dateStr = 'Scheduled Soon';
          final DateTime? startsAt = ApiService.parseDateTime(q['starts_at'] ?? q['scheduled_at']);
          if (startsAt != null) {
            final hour = startsAt.hour % 12 == 0 ? 12 : startsAt.hour % 12;
            final minute = startsAt.minute.toString().padLeft(2, '0');
            final ampm = startsAt.hour >= 12 ? 'PM' : 'AM';
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            dateStr = '${startsAt.day} ${months[startsAt.month - 1]} ${startsAt.year}, $hour:$minute $ampm';
          }

          mappedList.add({
            'id': q['id'],
            'title': q['title'],
            'subject': q['subject'] ?? 'General',
            'category': 'upcoming',
            'description': q['description'] ?? 'No description provided.',
            'questions': q['questions_count'] ?? 0,
            'duration': '${q['duration_minutes'] ?? 15} mins',
            'durationMinutes': q['duration_minutes'] ?? 15,
            'date': dateStr,
            'startsAt': startsAt,
            'instructor': q['instructor'] ?? 'Faculty',
            'color': const Color(0xFF0984E3),
            'icon': Icons.memory_rounded,
          });
        }

        // Archived/Backend completed quizzes
        for (var q in completedList) {
          if (!mappedList.any((item) => item['id'] == q['id'])) {
            mappedList.add({
              'id': q['id'],
              'title': q['title'],
              'subject': q['subject'] ?? 'General',
              'category': 'completed',
              'description': q['description'] ?? 'No description provided.',
              'score': 'Completed',
              'marks': 'Submitted',
              'date': 'Archived',
              'status': 'Passed',
              'color': const Color(0xFF00B894),
              'icon': Icons.task_alt_rounded,
            });
          }
        }

        _allQuizzes = mappedList;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredList(String category) {
    return _allQuizzes.where((quiz) {
      final matchesCategory = quiz['category'] == category;
      final matchesQuery = _searchQuery.isEmpty ||
          quiz['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quiz['subject'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,

      // App Bar with Search & Tabs
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        foregroundColor: AppTheme.mainText,
        title: const Text(
          'My Quizzes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.mainText),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(105),
          child: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search quizzes by title or subject...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),
              ),

              // Tab Selector Header
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                ],
              ),
            ],
          ),
        ),
      ),

      // Tab Views
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // 1. Active Quizzes Tab
            _buildQuizListView(
              quizzes: _getFilteredList('active'),
              builder: (quiz) => _buildActiveQuizCard(quiz),
              emptyTitle: 'No Active Quizzes',
              emptyMessage: 'You are all caught up! No active quizzes available right now.',
            ),

            // 2. Upcoming Quizzes Tab
            _buildQuizListView(
              quizzes: _getFilteredList('upcoming'),
              builder: (quiz) => _buildUpcomingQuizCard(quiz),
              emptyTitle: 'No Upcoming Quizzes',
              emptyMessage: 'There are no upcoming quizzes scheduled for the near future.',
            ),

            // 3. Completed Quizzes Tab
            _buildQuizListView(
              quizzes: _getFilteredList('completed'),
              builder: (quiz) => _buildCompletedQuizCard(quiz),
              emptyTitle: 'No Completed Quizzes',
              emptyMessage: 'You haven\'t completed any quizzes yet.',
            ),
          ],
        ),
      ),
    );
  }

  // Generic List View Builder with Empty State
  Widget _buildQuizListView({
    required List<Map<String, dynamic>> quizzes,
    required Widget Function(Map<String, dynamic> quiz) builder,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await _fetchQuizzesFromBackend();
      },
      child: quizzes.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
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
                            Icons.assignment_outlined,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: quizzes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => builder(quizzes[index]),
            ),
    );
  }

  // Card for Active Quiz
  Widget _buildActiveQuizCard(Map<String, dynamic> quiz) {
    final Color themeColor = quiz['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  quiz['subject'],
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Text(
                quiz['due'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            quiz['title'],
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Instructor: ${quiz['instructor']}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (quiz['description'] != null && quiz['description'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              quiz['description'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline_rounded, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${quiz['questions']} Qs',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_bottom_rounded, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          quiz['duration'],
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  if (quiz['isAttempted'] == true) {
                    CustomToast.show(
                      context,
                      title: 'Already Attempted',
                      message: 'You have already submitted your response for this quiz.',
                      type: ToastType.info,
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  );

                  List<Map<String, dynamic>> questions = [];
                  if (quiz['id'] != null && quiz['id'] is int) {
                    final quizDetails = await ApiService.getQuizDetails(quiz['id']);
                    if (quizDetails != null && quizDetails['questions'] is List && (quizDetails['questions'] as List).isNotEmpty) {
                      questions = List<Map<String, dynamic>>.from(
                        (quizDetails['questions'] as List).map((q) => {
                          'id': q['id'],
                          'question': q['question'],
                          'type': q['type'] ?? 'single',
                          'options': q['options'] is List ? List<String>.from(q['options']) : jsonDecode(q['options']),
                          'correct_option': q['correct_option'],
                        }),
                      );
                    }
                  }

                  if (!mounted) return;
                  Navigator.of(context).pop(); // Close loader

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
                    return; // User cancelled or permission refused
                  }

                  if (!mounted) return;

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => QuizAttemptScreen(
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
                    if (mounted) _fetchQuizzesFromBackend();
                  });
                },
                icon: Icon(
                  quiz['isAttempted'] == true ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                  size: 16,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: quiz['isAttempted'] == true ? const Color(0xFF00B894) : quiz['color'],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                label: Text(
                  quiz['isAttempted'] == true ? 'Attempted' : 'Attempt',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCompletedQuizDetailsModal(Map<String, dynamic> quiz) {
    final att = quiz['attemptData'];

    int score = 0;
    int totalQs = quiz['questions'] ?? 0;
    int percentage = 0;
    if (att != null) {
      score = att['score'] ?? 0;
      totalQs = att['total_questions'] ?? totalQs;
      percentage = totalQs > 0 ? ((score / totalQs) * 100).round() : 0;
    } else if (quiz['score'] != null && quiz['score'].toString().contains('%')) {
      percentage = int.tryParse(quiz['score'].toString().replaceAll('%', '')) ?? 0;
    }

    final bool passed = percentage >= 50;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                          quiz['title'] ?? 'Quiz Result',
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
                      color: (passed ? const Color(0xFF00B894) : const Color(0xFFFF7675)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          passed ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          size: 14,
                          color: passed ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          passed ? 'Passed' : 'Needs Review',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: passed ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quiz Description & Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D3436)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quiz['description'] ?? 'No description provided.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Attempt Score Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: passed
                        ? [const Color(0xFF00B894), const Color(0xFF55E6C1)]
                        : [const Color(0xFFFF7675), const Color(0xFFFAB1A0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: (passed ? const Color(0xFF00B894) : const Color(0xFFFF7675)).withValues(alpha: 0.3),
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
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        passed ? Icons.emoji_events_rounded : Icons.history_edu_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passed ? 'Congratulations! Passed' : 'Assessment Submitted',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Final Score: ${quiz['score'] ?? '$percentage%'} (${quiz['marks'] ?? '$score / $totalQs'})',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Total Questions',
                      value: '${quiz['questions']} Qs',
                      color: const Color(0xFF0984E3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: quiz['duration'] ?? '15 mins',
                      color: const Color(0xFFE17055),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Close Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D3436),
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

  // Card for Upcoming Quiz
  Widget _buildUpcomingQuizCard(Map<String, dynamic> quiz) {
    final Color themeColor = AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_note_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz['title'],
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Subject: ${quiz['subject']}  •  By ${quiz['instructor']}',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      quiz['date'],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mainText,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${quiz['questions']} Qs (${quiz['duration']})',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card for Completed Quiz
  Widget _buildCompletedQuizCard(Map<String, dynamic> quiz) {
    final Color themeColor = quiz['color'] as Color;

    return InkWell(
      onTap: () => _showCompletedQuizDetailsModal(quiz),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.08),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quiz['subject'] ?? 'General',
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: themeColor),
                      const SizedBox(width: 4),
                      Text(
                        quiz['status'] ?? 'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              quiz['title'],
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Instructor: ${quiz['instructor']}  •  ${quiz['questions']} Questions',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FINAL SCORE',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${quiz['score']} (${quiz['marks']})',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeColor),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: themeColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
