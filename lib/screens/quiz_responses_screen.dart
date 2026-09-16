import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';

class QuizResponsesScreen extends StatefulWidget {
  final Map<String, dynamic>? quiz;

  const QuizResponsesScreen({
    super.key,
    this.quiz,
  });

  @override
  State<QuizResponsesScreen> createState() => _QuizResponsesScreenState();
}

class _QuizResponsesScreenState extends State<QuizResponsesScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _facultyQuizzes = [];
  Map<String, dynamic>? _selectedQuiz;
  String _selectedBatchFilter = 'ALL'; // 'ALL' or specific batch name

  List<Map<String, dynamic>> _allSubmissions = [];

  @override
  void initState() {
    super.initState();
    _selectedQuiz = widget.quiz;
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.getQuizzes(status: 'all'),
        ApiService.getFacultySubmissions(),
      ]);

      if (!mounted) return;

      final quizzes = List<Map<String, dynamic>>.from(results[0]);
      final submissions = List<Map<String, dynamic>>.from(results[1]);

      setState(() {
        _facultyQuizzes = quizzes;
        _allSubmissions = submissions;

        // If no quiz was passed in constructor, select the first available quiz by default
        if (_selectedQuiz == null && _facultyQuizzes.isNotEmpty) {
          _selectedQuiz = _facultyQuizzes.first;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(context, message: 'Failed to load responses: $e', type: ToastType.error);
      }
    }
  }

  /// Helper to extract standardized Batch label from student profile in submission
  String _getBatchLabelForSubmission(Map<String, dynamic> sub) {
    final user = sub['user'] is Map ? sub['user'] : {};
    
    final branchObj = user['branch'];
    String branch = '';
    if (branchObj is Map) {
      branch = (branchObj['code'] ?? branchObj['name'] ?? '').toString();
    } else if (branchObj != null) {
      branch = branchObj.toString();
    }

    final secObj = user['section'];
    String section = '';
    if (secObj is Map) {
      section = (secObj['name'] ?? '').toString();
    } else if (secObj != null) {
      section = secObj.toString();
    }

    final String semester = (user['semester'] ?? '').toString().trim();

    List<String> parts = [];
    if (branch.isNotEmpty) parts.add(branch);
    if (section.isNotEmpty) parts.add('Sec $section');
    if (semester.isNotEmpty) parts.add(semester.startsWith('Sem') ? semester : 'Sem $semester');

    if (parts.isNotEmpty) return parts.join(' - ');

    final dept = user['department'] ?? sub['department'];
    if (dept != null && dept.toString().trim().isNotEmpty) {
      return dept.toString().trim();
    }

    return 'General Batch';
  }

  /// Get submissions filtered by currently selected quiz and search query
  List<Map<String, dynamic>> get _currentQuizSubmissions {
    if (_selectedQuiz == null) return [];

    final targetQuizId = _selectedQuiz!['id']?.toString();

    final quizSubmissions = _allSubmissions.where((sub) {
      final subQuizId = sub['quiz_id']?.toString() ??
          (sub['quiz'] is Map ? sub['quiz']['id']?.toString() : null);
      return subQuizId == targetQuizId;
    }).toList();

    if (_searchQuery.isEmpty) return quizSubmissions;

    final q = _searchQuery.toLowerCase();
    return quizSubmissions.where((sub) {
      final user = sub['user'] is Map ? sub['user'] : {};
      final name = (user['name'] ?? sub['student_name'] ?? '').toString().toLowerCase();
      final roll = (user['roll_number'] ?? sub['roll_number'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? sub['student_email'] ?? '').toString().toLowerCase();

      return name.contains(q) || roll.contains(q) || email.contains(q);
    }).toList();
  }

  /// Extract list of unique batches present in current quiz submissions
  List<String> get _availableBatches {
    final Set<String> batches = {'ALL'};
    for (var sub in _currentQuizSubmissions) {
      batches.add(_getBatchLabelForSubmission(sub));
    }
    return batches.toList();
  }

  /// Get final submissions list based on batch filter ('ALL' or specific batch)
  List<Map<String, dynamic>> get _filteredSubmissions {
    final subs = _currentQuizSubmissions;
    if (_selectedBatchFilter == 'ALL') return subs;
    return subs.where((sub) => _getBatchLabelForSubmission(sub) == _selectedBatchFilter).toList();
  }

  /// Group submissions by batch for the "ALL" view
  Map<String, List<Map<String, dynamic>>> get _groupedSubmissionsByBatch {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var sub in _currentQuizSubmissions) {
      final batchLabel = _getBatchLabelForSubmission(sub);
      grouped.putIfAbsent(batchLabel, () => []).add(sub);
    }
    return grouped;
  }

  double _calculateAvgScore(List<Map<String, dynamic>> subs) {
    if (subs.isEmpty) return 0.0;
    double totalPct = 0;
    for (var sub in subs) {
      final score = (sub['score'] ?? 0).toDouble();
      final totalQ = (sub['total_questions'] ?? 1).toDouble();
      final pct = totalQ > 0 ? (score / totalQ) * 100 : 0.0;
      totalPct += pct;
    }
    return totalPct / subs.length;
  }

  int _calculatePassedCount(List<Map<String, dynamic>> subs) {
    int count = 0;
    for (var sub in subs) {
      final score = (sub['score'] ?? 0).toDouble();
      final totalQ = (sub['total_questions'] ?? 1).toDouble();
      final pct = totalQ > 0 ? (score / totalQ) * 100 : 0.0;
      if (pct >= 50.0) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final currentSubmissions = _currentQuizSubmissions;
    final avgScore = _calculateAvgScore(currentSubmissions);
    final passedCount = _calculatePassedCount(currentSubmissions);
    final batchesList = _availableBatches;

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
          'Quiz Analytics & Responses',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _loadInitialData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 1: Select Quiz Card Header
                    _buildQuizSelectorCard(),

                    const SizedBox(height: 16),

                    if (_selectedQuiz == null)
                      _buildNoQuizSelectedView()
                    else ...[
                      // Metrics Overview Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Responses',
                              value: '${currentSubmissions.length}',
                              icon: Icons.people_alt_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Avg Accuracy',
                              value: '${avgScore.toStringAsFixed(1)}%',
                              icon: Icons.analytics_rounded,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Passed (≥50%)',
                              value: '$passedCount/${currentSubmissions.length}',
                              icon: Icons.check_circle_rounded,
                              color: AppTheme.success,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Step 2: Batch Filter Selector & Scope Bar
                      _buildBatchFilterSelector(batchesList),

                      const SizedBox(height: 16),

                      // Search Input
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search student name or roll number...',
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

                      const SizedBox(height: 16),

                      // Step 3: Responses List (Grouped by batch if ALL is selected, or filtered list)
                      if (_selectedBatchFilter == 'ALL')
                        _buildGroupedResponsesView()
                      else
                        _buildSingleBatchResponsesView(_filteredSubmissions),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  /// Step 1 UI: Select Quiz Card
  Widget _buildQuizSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.quiz_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Select Quiz to View Responses',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                value: _selectedQuiz,
                hint: const Text('Choose a quiz from your list...', style: TextStyle(fontSize: 14)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                items: _facultyQuizzes.map((quiz) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: quiz,
                    child: Text(
                      quiz['title'] ?? 'Untitled Quiz',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  );
                }).toList(),
                onChanged: (quiz) {
                  setState(() {
                    _selectedQuiz = quiz;
                    _selectedBatchFilter = 'ALL';
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2 UI: Batch Scope Filter Selector
  Widget _buildBatchFilterSelector(List<String> batchesList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by Target Batch:',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: batchesList.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final batch = batchesList[index];
              final isSelected = _selectedBatchFilter == batch;
              final label = batch == 'ALL' ? 'All Batches (Grouped)' : batch;

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : const Color(0xFFCBD5E1),
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() => _selectedBatchFilter = batch);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// View when ALL batches is selected: Groups responses section by section per Batch
  Widget _buildGroupedResponsesView() {
    final grouped = _groupedSubmissionsByBatch;

    if (grouped.isEmpty) {
      return _buildEmptyView('No student responses submitted for this quiz yet.');
    }

    return Column(
      children: grouped.entries.map((entry) {
        final batchName = entry.key;
        final subs = entry.value;
        final avgBatchScore = _calculateAvgScore(subs);
        final passedBatchCount = _calculatePassedCount(subs);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batchName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${subs.length} Submissions • Avg: ${avgBatchScore.toStringAsFixed(1)}% • Passed: $passedBatchCount/${subs.length}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subs.length,
                    itemBuilder: (context, index) {
                      return _buildResponseCard(subs[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// View when a specific batch is selected
  Widget _buildSingleBatchResponsesView(List<Map<String, dynamic>> subs) {
    if (subs.isEmpty) {
      return _buildEmptyView('No responses found for batch "$_selectedBatchFilter".');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subs.length,
      itemBuilder: (context, index) {
        return _buildResponseCard(subs[index]);
      },
    );
  }

  Widget _buildNoQuizSelectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: const [
            Icon(Icons.touch_app_rounded, size: 54, color: Color(0xFF94A3B8)),
            SizedBox(height: 14),
            Text(
              'No Quiz Selected',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Please select a quiz from the dropdown above to view student responses and batch analytics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late_outlined, size: 52, color: Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            const Text(
              'No Responses Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseCard(Map<String, dynamic> sub) {
    final user = sub['user'] is Map ? sub['user'] : {};
    final String name = user['name'] ?? sub['student_name'] ?? 'Student';
    final String roll = user['roll_number'] ?? sub['roll_number'] ?? 'N/A';
    final String avatar = (user['avatar'] ?? '').toString();
    final String batchLabel = _getBatchLabelForSubmission(sub);

    final quizObj = sub['quiz'] is Map ? sub['quiz'] : {};

    final int score = sub['score'] ?? 0;
    final int totalQ = sub['total_questions'] ?? (quizObj['total_questions'] ?? 0);
    final double pct = totalQ > 0 ? (score / totalQ) * 100 : 0.0;

    final String subType = (sub['submission_type'] ?? 'manual').toString().toLowerCase();
    final bool isAuto = subType == 'auto';
    final String autoReason = sub['auto_submit_reason'] ?? 'Tab Switch / Timeout';
    final int violations = sub['violations_count'] ?? 0;
    final String rawDate = sub['created_at'] ?? sub['submitted_at'] ?? '';
    final String formattedDate = _formatDate(rawDate);

    final bool isPassed = pct >= 50.0;
    final Color scoreColor = isPassed ? const Color(0xFF047857) : AppTheme.error;
    final Color scoreBg = isPassed ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Student Profile + Score Pill
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Roll No: $roll',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Score Badge Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: scoreBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$score / $totalQ',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2: Target Batch Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_rounded, size: 14, color: Color(0xFF475569)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      batchLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Row 3: Submission Status + Time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAuto ? const Color(0xFFFFF5F5) : const Color(0xFFE6FFFA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAuto ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                        size: 13,
                        color: isAuto ? const Color(0xFFE53E3E) : const Color(0xFF047857),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAuto ? 'AUTO SUBMIT ($violations Vio)' : 'MANUAL SUBMIT',
                        style: TextStyle(
                          color: isAuto ? const Color(0xFFE53E3E) : const Color(0xFF047857),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (isAuto && autoReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: $autoReason',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFFE53E3E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Row 4: Reattempt Action & Checks
            _buildReattemptActionRow(sub, name),
          ],
        ),
      ),
    );
  }

  Widget _buildReattemptActionRow(Map<String, dynamic> sub, String studentName) {
    final int attemptId = sub['id'] ?? 0;
    final String rawDate = sub['created_at'] ?? sub['submitted_at'] ?? '';
    final DateTime? submittedAt = DateTime.tryParse(rawDate)?.toLocal();
    final bool isOlderThan3Hours = submittedAt != null && DateTime.now().difference(submittedAt).inHours >= 3;

    final quizObj = sub['quiz'] is Map ? sub['quiz'] : (_selectedQuiz ?? {});
    final String quizStatus = (quizObj['status'] ?? 'active').toString().toLowerCase();
    final String endsAtIso = (quizObj['ends_at'] ?? '').toString();
    final DateTime? quizEndsAt = endsAtIso.isNotEmpty ? DateTime.tryParse(endsAtIso)?.toLocal() : null;
    final bool isQuizExpired = (quizStatus != 'active' && quizStatus != 'scheduled') ||
        (quizEndsAt != null && DateTime.now().isAfter(quizEndsAt));

    if (isOlderThan3Hours) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: const [
            Icon(Icons.history_toggle_off_rounded, size: 14, color: Color(0xFF64748B)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Reattempt Locked: Submitted > 3 hours ago',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (isQuizExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: const [
            Icon(Icons.event_busy_rounded, size: 14, color: AppTheme.error),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Reattempt Locked: Quiz deadline has ended',
                style: TextStyle(fontSize: 11.5, color: AppTheme.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handleGrantReattemptDialog(attemptId, studentName),
        icon: const Icon(Icons.restart_alt_rounded, size: 16),
        label: const Text('Allow Reattempt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: const BorderSide(color: AppTheme.primary),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  /// Open dialog asking faculty for Reattempt Reason with backend eligibility check
  Future<void> _handleGrantReattemptDialog(int attemptId, String studentName) async {
    // 1. First check server eligibility
    CustomToast.show(context, message: 'Verifying reattempt eligibility...', type: ToastType.info);
    final check = await ApiService.checkReattemptEligibility(attemptId);

    if (!mounted) return;

    if (check['eligible'] != true) {
      final String reasonMsg = check['reason'] ?? 'Reattempt cannot be granted for this attempt.';
      CustomToast.show(context, title: 'Ineligible for Reattempt', message: reasonMsg, type: ToastType.error);
      return;
    }

    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          backgroundColor: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.restart_alt_rounded, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Allow Quiz Reattempt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Student & Warning Info Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                            children: [
                              const TextSpan(text: 'Grant 1-time reattempt to '),
                              TextSpan(
                                text: studentName,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                              const TextSpan(text: '?'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'This will reset the student\'s previous submission so they can retake this quiz.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Reason Input Label & TextField
                  const Text(
                    'Reason for Reattempt *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Technical failure during submission...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (reasonController.text.trim().length < 5) {
                            CustomToast.show(ctx, message: 'Please enter a valid reason (min 5 characters)', type: ToastType.warning);
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm & Grant', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm == true && mounted) {
      final String reasonText = reasonController.text.trim();
      setState(() => _isLoading = true);

      final res = await ApiService.grantFacultyReattempt(
        attemptId: attemptId,
        reason: reasonText,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        CustomToast.show(
          context,
          title: 'Reattempt Granted',
          message: res['message'] ?? 'Reattempt granted successfully!',
          type: ToastType.success,
        );
        _loadInitialData();
      } else {
        setState(() => _isLoading = false);
        CustomToast.show(
          context,
          title: 'Failed to Grant Reattempt',
          message: res['message'] ?? 'Could not grant reattempt.',
          type: ToastType.error,
        );
      }
    }
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return isoString;

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[dt.month - 1];
    final hr = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');

    return '${dt.day} $m ${dt.year}, $hr:$min $period';
  }
}
