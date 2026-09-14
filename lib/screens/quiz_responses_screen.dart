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
  List<Map<String, dynamic>> _allSubmissions = [];

  @override
  void initState() {
    super.initState();
    _fetchResponses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchResponses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final rawSubmissions = await ApiService.getFacultySubmissions();
      if (!mounted) return;

      final targetQuizId = widget.quiz?['id']?.toString();

      final filtered = rawSubmissions.where((sub) {
        if (targetQuizId == null) return true;

        final subQuizId = sub['quiz_id']?.toString() ??
            (sub['quiz'] is Map ? sub['quiz']['id']?.toString() : null);

        return subQuizId == targetQuizId;
      }).toList();

      setState(() {
        _allSubmissions = filtered;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(context, message: 'Failed to load responses: $e', type: ToastType.error);
      }
    }
  }

  List<Map<String, dynamic>> get _displaySubmissions {
    if (_searchQuery.isEmpty) return _allSubmissions;

    final q = _searchQuery.toLowerCase();
    return _allSubmissions.where((sub) {
      final user = sub['user'] is Map ? sub['user'] : {};
      final name = (user['name'] ?? sub['student_name'] ?? '').toString().toLowerCase();
      final roll = (user['roll_number'] ?? sub['roll_number'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? sub['student_email'] ?? '').toString().toLowerCase();
      final quizTitle = (sub['quiz'] is Map ? sub['quiz']['title'] : sub['quiz_title'] ?? '').toString().toLowerCase();

      return name.contains(q) || roll.contains(q) || email.contains(q) || quizTitle.contains(q);
    }).toList();
  }

  double get _averagePercentage {
    if (_allSubmissions.isEmpty) return 0.0;
    double totalPct = 0;
    for (var sub in _allSubmissions) {
      final score = (sub['score'] ?? 0).toDouble();
      final totalQ = (sub['total_questions'] ?? 1).toDouble();
      final pct = totalQ > 0 ? (score / totalQ) * 100 : 0.0;
      totalPct += pct;
    }
    return totalPct / _allSubmissions.length;
  }

  int get _passedCount {
    int count = 0;
    for (var sub in _allSubmissions) {
      final score = (sub['score'] ?? 0).toDouble();
      final totalQ = (sub['total_questions'] ?? 1).toDouble();
      final pct = totalQ > 0 ? (score / totalQ) * 100 : 0.0;
      if (pct >= 50.0) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final quizTitle = widget.quiz?['title'] ?? 'Student Quiz Responses';
    final quizSubject = widget.quiz?['subject'] ?? 'All Quizzes Overview';

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quizTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              quizSubject,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _fetchResponses,
            tooltip: 'Refresh Responses',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _fetchResponses,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metrics Overview Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Total Responses',
                            value: '${_allSubmissions.length}',
                            icon: Icons.people_alt_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Avg Accuracy',
                            value: '${_averagePercentage.toStringAsFixed(1)}%',
                            icon: Icons.analytics_rounded,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Passed (≥50%)',
                            value: '$_passedCount/${_allSubmissions.length}',
                            icon: Icons.check_circle_rounded,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Search Bar Input
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
                          hintText: 'Search by student name, roll no, email...',
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

                    // Submissions Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Student Submissions (${_displaySubmissions.length})',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Responses List
                    if (_displaySubmissions.isEmpty)
                      _buildEmptyView()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _displaySubmissions.length,
                        itemBuilder: (context, index) {
                          final sub = _displaySubmissions[index];
                          return _buildResponseCard(sub);
                        },
                      ),
                  ],
                ),
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

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.assignment_late_outlined, size: 52, color: Color(0xFF94A3B8)),
            SizedBox(height: 14),
            Text(
              'No Responses Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Student submissions for this quiz will appear here once attempts are completed.',
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

  Widget _buildResponseCard(Map<String, dynamic> sub) {
    final user = sub['user'] is Map ? sub['user'] : {};
    final String name = user['name'] ?? sub['student_name'] ?? 'Student';
    final String email = user['email'] ?? sub['student_email'] ?? 'N/A';
    final String roll = user['roll_number'] ?? sub['roll_number'] ?? 'N/A';
    final String avatar = (user['avatar'] ?? '').toString();

    final quizObj = sub['quiz'] is Map ? sub['quiz'] : {};
    final String quizTitle = quizObj['title'] ?? sub['quiz_title'] ?? 'Quiz';

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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Student info + Score Pill
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                            fontSize: 15,
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Roll: $roll • $email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$score / $totalQ',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (widget.quiz == null) ...[
              const SizedBox(height: 8),
              Text(
                'Quiz: $quizTitle',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Bottom Badges Row: Submission mode & Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          ],
        ),
      ),
    );
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
