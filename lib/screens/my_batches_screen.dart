import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'create_quiz_screen.dart';

class MyBatchesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialAllocations;
  final Map<String, dynamic> userData;

  const MyBatchesScreen({
    super.key,
    required this.initialAllocations,
    required this.userData,
  });

  @override
  State<MyBatchesScreen> createState() => _MyBatchesScreenState();
}

class _MyBatchesScreenState extends State<MyBatchesScreen> {
  late List<Map<String, dynamic>> _allocations;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _allocations = List<Map<String, dynamic>>.from(widget.initialAllocations);
    if (_allocations.isEmpty) {
      _fetchAllocations();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllocations() async {
    setState(() => _isLoading = true);
    try {
      final allocs = await ApiService.getMyFacultyAllocations();
      if (mounted) {
        setState(() {
          _allocations = allocs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(
          context,
          title: 'Fetch Error',
          message: 'Failed to load batch allocations: $e',
          type: ToastType.error,
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAllocations {
    if (_searchQuery.trim().isEmpty) return _allocations;
    final query = _searchQuery.toLowerCase();
    return _allocations.where((alloc) {
      final subject = (alloc['subject_name'] ?? alloc['subject'] ?? alloc['subject_code'] ?? '').toString().toLowerCase();
      final branch = (alloc['branch_name'] ?? alloc['branch_code'] ?? alloc['branch'] ?? '').toString().toLowerCase();
      final section = (alloc['section_name'] ?? alloc['section'] ?? '').toString().toLowerCase();
      final dept = (alloc['department_name'] ?? alloc['department'] ?? '').toString().toLowerCase();
      final sem = (alloc['semester'] ?? alloc['academic_year'] ?? '').toString().toLowerCase();

      return subject.contains(query) ||
          branch.contains(query) ||
          section.contains(query) ||
          dept.contains(query) ||
          sem.contains(query);
    }).toList();
  }

  String _formatBatchLabel(Map<String, dynamic> alloc) {
    final branchCode = alloc['branch_code'] ??
        alloc['code'] ??
        alloc['branchModel']?['code'] ??
        alloc['branch_name']?.toString().split(' ').first ??
        alloc['branch'] ??
        'Branch';
    final sec = alloc['section_name'] ?? alloc['section'] ?? 'A';
    final subject = alloc['subject_name'] ?? alloc['subject'] ?? 'Subject';
    final rawSem = alloc['semester'] ?? alloc['sem'] ?? alloc['academic_year'] ?? '';

    String semStr = rawSem.toString().trim();
    if (semStr.isNotEmpty) {
      final numMatch = RegExp(r'\d+').firstMatch(semStr);
      if (numMatch != null) {
        semStr = 'Sem ${numMatch.group(0)}';
      } else {
        semStr = 'Sem $semStr';
      }
    } else {
      semStr = 'Sem N/A';
    }

    return '$branchCode ($sec) - $subject - $semStr';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAllocations;
    final totalBatches = _allocations.length;
    final uniqueSubjects = _allocations.map((a) => a['subject_name'] ?? a['subject']).toSet().where((s) => s != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'My Allocated Batches',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.mainText,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Allocations',
            onPressed: _fetchAllocations,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllocations,
        color: AppTheme.primary,
        child: Column(
          children: [
            // Top Summary Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryBadge(
                          icon: Icons.groups_rounded,
                          title: 'Allocated Batches',
                          value: '$totalBatches',
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryBadge(
                          icon: Icons.menu_book_rounded,
                          title: 'Assigned Subjects',
                          value: '$uniqueSubjects',
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by subject, branch, section, sem...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final alloc = filtered[index];
                            return _buildBatchCard(alloc);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBadge({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
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
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.mainText,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> alloc) {
    final subjectName = (alloc['subject_name'] ?? alloc['subject'] ?? 'Subject').toString();
    final subjectCode = (alloc['subject_code'] ?? alloc['code'] ?? '').toString();
    final branchName = (alloc['branch_name'] ?? alloc['branch'] ?? alloc['branch_code'] ?? 'Branch').toString();
    final deptName = (alloc['department_name'] ?? alloc['department'] ?? '').toString();
    final courseName = (alloc['course_name'] ?? alloc['course'] ?? '').toString();
    final sectionName = (alloc['section_name'] ?? alloc['section'] ?? 'A').toString();
    final rawSem = (alloc['semester'] ?? alloc['sem'] ?? alloc['academic_year'] ?? '').toString();

    String semDisplay = rawSem.trim();
    if (semDisplay.isNotEmpty) {
      final match = RegExp(r'\d+').firstMatch(semDisplay);
      if (match != null) {
        semDisplay = 'Semester ${match.group(0)}';
      } else {
        semDisplay = 'Semester $semDisplay';
      }
    } else {
      semDisplay = 'Semester N/A';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          // Card Header with Subject Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mainText,
                        ),
                      ),
                      if (subjectCode.isNotEmpty)
                        Text(
                          'Code: $subjectCode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Section $sectionName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Grid
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailTile(
                        icon: Icons.alt_route_rounded,
                        label: 'Branch',
                        value: branchName,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailTile(
                        icon: Icons.business_center_rounded,
                        label: 'Department',
                        value: deptName.isNotEmpty ? deptName : 'N/A',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailTile(
                        icon: Icons.school_rounded,
                        label: 'Course',
                        value: courseName.isNotEmpty ? courseName : 'N/A',
                      ),
                    ),
                    Expanded(
                      child: _buildDetailTile(
                        icon: Icons.calendar_view_week_rounded,
                        label: 'Academic Scope',
                        value: semDisplay,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Card Action Footer
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Create Quiz for this Batch'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateQuizScreen(
                                userData: widget.userData,
                                allocations: _allocations,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mainText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 56,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No Matching Batches Found' : 'No Allocated Batches Assigned',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.mainText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with a different subject, branch, or section keyword.'
                  : 'You do not have any subject or section allocations assigned by the administrator yet. Contact your department admin to assign batches.',
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Clear Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
