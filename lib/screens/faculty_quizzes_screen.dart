import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'create_quiz_screen.dart';
import 'manage_questions_screen.dart';

class FacultyQuizzesScreen extends StatefulWidget {
  final int initialTabIndex;
  final Map<String, dynamic>? userData;
  final List<Map<String, dynamic>>? allocations;

  const FacultyQuizzesScreen({
    super.key,
    this.initialTabIndex = 0,
    this.userData,
    this.allocations,
  });

  @override
  State<FacultyQuizzesScreen> createState() => _FacultyQuizzesScreenState();
}

class _FacultyQuizzesScreenState extends State<FacultyQuizzesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allQuizzes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _fetchQuizzes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuizzes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final rawQuizzes = await ApiService.getQuizzes(status: 'all');
      if (mounted) {
        setState(() {
          _allQuizzes = List<Map<String, dynamic>>.from(rawQuizzes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(context, message: 'Error loading quizzes: $e', type: ToastType.error);
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredQuizzes(String tabCategory) {
    return _allQuizzes.where((quiz) {
      final status = (quiz['status'] ?? '').toString().toLowerCase();
      final title = (quiz['title'] ?? '').toString().toLowerCase();
      final subject = (quiz['subject'] ?? '').toString().toLowerCase();
      final code = (quiz['quiz_code'] ?? '').toString().toLowerCase();
      
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          subject.contains(_searchQuery.toLowerCase()) ||
          code.contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (tabCategory == 'active') {
        return status == 'active' || status == 'published' || status == 'live' || quiz['is_active'] == 1 || quiz['is_active'] == true;
      } else if (tabCategory == 'scheduled') {
        return status == 'scheduled' || status == 'draft' || status == 'pending';
      } else if (tabCategory == 'completed') {
        return status == 'completed' || status == 'closed' || status == 'archived' || status == 'inactive';
      }

      return true;
    }).toList();
  }

  Future<void> _deleteQuiz(int quizId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 28),
            SizedBox(width: 10),
            Text('Delete Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone and will delete all student attempt history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final success = await ApiService.deleteQuiz(quizId);
      if (!mounted) return;
      if (success) {
        CustomToast.show(context, message: 'Quiz deleted successfully', type: ToastType.success);
        _fetchQuizzes();
      } else {
        setState(() => _isLoading = false);
        CustomToast.show(context, message: 'Failed to delete quiz', type: ToastType.error);
      }
    }
  }

  void _navigateToCreateQuiz([Map<String, dynamic>? quizToEdit]) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateQuizScreen(
          userData: widget.userData ?? {},
          allocations: widget.allocations ?? [],
          quizToEdit: quizToEdit,
        ),
      ),
    );
    if (res == true && mounted) {
      _fetchQuizzes();
    }
  }

  void _navigateToManageQuestions(Map<String, dynamic> quiz) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageQuestionsScreen(quiz: quiz),
      ),
    );
    if (res == true && mounted) {
      _fetchQuizzes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _getFilteredQuizzes('active');
    final scheduledList = _getFilteredQuizzes('scheduled');
    final completedList = _getFilteredQuizzes('completed');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Quiz Management',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _fetchQuizzes,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search title, subject or code...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),

              // TabBar (Active, Scheduled, Completed)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 15),
                          const SizedBox(width: 4),
                          Text('Active (${activeList.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 15),
                          const SizedBox(width: 4),
                          Text('Scheduled (${scheduledList.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 15),
                          const SizedBox(width: 4),
                          Text('Completed (${completedList.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildQuizListView(activeList, 'No Active Quizzes Found', 'Create a new quiz or publish a draft quiz to get started.', Icons.bolt_rounded, AppTheme.success),
                _buildQuizListView(scheduledList, 'No Scheduled Quizzes', 'Quizzes in draft or scheduled state will appear here.', Icons.event_note_rounded, AppTheme.primary),
                _buildQuizListView(completedList, 'No Completed Quizzes', 'Past and closed assessment quizzes will appear here.', Icons.task_alt_rounded, Colors.purple),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateQuiz(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Create Quiz',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildQuizListView(
    List<Map<String, dynamic>> quizzes,
    String emptyTitle,
    String emptySubtitle,
    IconData emptyIcon,
    Color themeColor,
  ) {
    if (quizzes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(emptyIcon, size: 54, color: themeColor),
              ),
              const SizedBox(height: 18),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _navigateToCreateQuiz(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text('Create New Quiz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quizzes.length,
      itemBuilder: (context, index) {
        final quiz = quizzes[index];
        return _buildQuizCard(quiz);
      },
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> quiz) {
    final int quizId = quiz['id'] ?? 0;
    final String title = quiz['title'] ?? 'Untitled Quiz';
    final String subject = quiz['subject'] ?? 'General';
    final String status = (quiz['status'] ?? 'active').toString().toLowerCase();
    final String code = quiz['quiz_code'] ?? '';
    final int questionsCount = (quiz['questions'] is List)
        ? (quiz['questions'] as List).length
        : (quiz['questions_count'] ?? 0);
    final int duration = quiz['duration'] ?? 30;
    final int totalMarks = quiz['total_marks'] ?? (questionsCount * 1);
    final String branchName = quiz['branch_name'] ?? quiz['department'] ?? 'All Branches';
    final String sectionName = quiz['section_name'] ?? 'All Sections';

    Color statusBg = Colors.green.shade50;
    Color statusColor = Colors.green.shade700;
    String statusLabel = 'ACTIVE';

    if (status == 'scheduled' || status == 'draft' || status == 'pending') {
      statusBg = Colors.blue.shade50;
      statusColor = Colors.blue.shade700;
      statusLabel = status.toUpperCase();
    } else if (status == 'completed' || status == 'closed' || status == 'archived') {
      statusBg = Colors.grey.shade100;
      statusColor = Colors.grey.shade700;
      statusLabel = status.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (code.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'CODE: $code',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$subject • $branchName ($sectionName)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Popup Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _navigateToCreateQuiz(quiz);
                    } else if (val == 'questions') {
                      _navigateToManageQuestions(quiz);
                    } else if (val == 'delete') {
                      _deleteQuiz(quizId, title);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'questions',
                      child: Row(
                        children: [
                          Icon(Icons.quiz_outlined, size: 18, color: Color(0xFF3B82F6)),
                          SizedBox(width: 10),
                          Text('Manage Questions'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF10B981)),
                          SizedBox(width: 10),
                          Text('Edit Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                          SizedBox(width: 10),
                          Text('Delete Quiz', style: TextStyle(color: AppTheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Info Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(Icons.help_outline_rounded, '$questionsCount Qs'),
                _buildInfoChip(Icons.timer_outlined, '$duration Mins'),
                _buildInfoChip(Icons.stars_rounded, '$totalMarks Marks'),
              ],
            ),
          ),

          // Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToManageQuestions(quiz),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.format_list_bulleted_rounded, size: 16, color: Color(0xFF334155)),
                    label: const Text('Questions', style: TextStyle(color: Color(0xFF334155), fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToCreateQuiz(quiz),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                    label: const Text('Edit Quiz', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
