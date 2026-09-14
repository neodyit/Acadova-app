import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'academic_profile_screen.dart';
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
  int _currentTabIndex = 0; // 0: Quizzes, 1: Submissions

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
      _quizzes = List<Map<String, dynamic>>.from(rawQuizzes);

      // 4. Fetch Student Submissions
      final rawSubmissions = await ApiService.getFacultySubmissions();
      _submissions = List<Map<String, dynamic>>.from(rawSubmissions);

      // 5. Fetch Faculty Allocations (Subjects & Sections)
      _allocations = await ApiService.getMyFacultyAllocations();
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showCreateQuizModal() {
    final titleController = TextEditingController();
    final durationController = TextEditingController(text: '15');
    final descriptionController = TextEditingController();

    String selectedSubject = _allocations.isNotEmpty
        ? (_allocations.first['subject_name'] ?? _user['department'] ?? 'Computer Science')
        : (_user['department'] ?? 'Computer Science');
    String selectedStatus = 'active';

    List<dynamic> targetDeptIds = ['all'];
    List<dynamic> targetCourseIds = ['all'];
    List<dynamic> targetBranchIds = ['all'];
    List<dynamic> targetSectionIds = ['all'];
    List<dynamic> targetSubjectIds = ['all'];

    String formatBatchLabel(Map<String, dynamic> alloc) {
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
        // Format semester into short form, e.g. "3rd Semester" -> "Sem 3", "3" -> "Sem 3"
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

    // Pre-populate target batches with all allocated batches by default
    Set<String> selectedBatches = _allocations.map((a) => formatBatchLabel(a)).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bool isAllBatchesSelected = _allocations.isNotEmpty &&
                selectedBatches.length == _allocations.length;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                      const Text(
                        'Create New Quiz',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mainText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 1. Quiz Title
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Quiz Title *',
                          prefixIcon: Icon(Icons.quiz_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Description / Instructions
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description / Instructions',
                          prefixIcon: Icon(Icons.description_rounded),
                          hintText: 'Enter quiz rules, guidelines, or instructions...',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Target Batches (Allocated Batches with Checkboxes & Select All)
                      if (_allocations.isNotEmpty) ...[
                        const Text(
                          'Target Batches *',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.mainText),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              children: [
                                // Select All row
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  title: const Text(
                                    'Select All Batches',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.primary),
                                  ),
                                  value: isAllBatchesSelected,
                                  activeColor: AppTheme.primary,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedBatches = _allocations.map((a) => formatBatchLabel(a)).toSet();
                                      } else {
                                        selectedBatches.clear();
                                      }
                                    });
                                  },
                                ),
                                const Divider(height: 1),
                                // Individual allocated batch checkboxes
                                ..._allocations.map((alloc) {
                                  final batchLabel = formatBatchLabel(alloc);
                                  final isSelected = selectedBatches.contains(batchLabel);

                                  return CheckboxListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    title: Text(
                                      batchLabel,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    value: isSelected,
                                    activeColor: AppTheme.primary,
                                    onChanged: (checked) {
                                      setModalState(() {
                                        if (checked == true) {
                                          selectedBatches.add(batchLabel);
                                        } else {
                                          selectedBatches.remove(batchLabel);
                                        }
                                      });
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 4 & 5. Duration and Status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (Mins) *',
                                prefixIcon: Icon(Icons.timer_rounded),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status *',
                                prefixIcon: Icon(Icons.flag_rounded),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Active', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'upcoming', child: Text('Upcoming', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedStatus = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final duration = int.tryParse(durationController.text.trim()) ?? 15;

                            if (title.isEmpty) {
                              CustomToast.show(
                                sheetContext,
                                message: 'Please enter quiz title',
                                type: ToastType.warning,
                              );
                              return;
                            }

                            List<Map<String, dynamic>> targetGroups = [];

                            // If specific batches were selected, update target filters and build specific target pairs (target_groups)
                            if (selectedBatches.isNotEmpty) {
                              final matchingAllocs = _allocations.where((a) {
                                return selectedBatches.contains(formatBatchLabel(a));
                              }).toList();

                              targetSectionIds = matchingAllocs.map((a) => a['section_id']).where((id) => id != null).toList();
                              targetDeptIds = matchingAllocs.map((a) => a['department_id']).where((id) => id != null).toList();
                              targetCourseIds = matchingAllocs.map((a) => a['course_id']).where((id) => id != null).toList();
                              targetBranchIds = matchingAllocs.map((a) => a['branch_id']).where((id) => id != null).toList();
                              targetSubjectIds = matchingAllocs.map((a) => a['subject_id'] ?? a['subject_name']).where((id) => id != null).toList();

                              // Construct explicit Target Pairs (target_groups) matching Admin Panel schema
                              targetGroups = matchingAllocs.map((alloc) {
                                final branchVal = alloc['branch_name'] ?? alloc['branch_code'] ?? alloc['branch_id'] ?? 'all';
                                final secVal = (alloc['section_name'] ?? alloc['section_id'] ?? 'all').toString();
                                final rawSem = alloc['semester'] ?? alloc['sem'] ?? alloc['academic_year'] ?? '';

                                String semVal = rawSem.toString().trim();
                                if (semVal.isNotEmpty) {
                                  final numMatch = RegExp(r'\d+').firstMatch(semVal);
                                  if (numMatch != null) {
                                    semVal = numMatch.group(0)!;
                                  }
                                }

                                return {
                                  'branch_id': branchVal,
                                  'section_id': secVal,
                                  'section_ids': [secVal],
                                  if (semVal.isNotEmpty) 'semester': semVal,
                                  if (alloc['department_id'] != null) 'department_id': alloc['department_id'],
                                  if (alloc['course_id'] != null) 'course_id': alloc['course_id'],
                                };
                              }).toList();

                              if (matchingAllocs.isNotEmpty) {
                                selectedSubject = matchingAllocs.first['subject_name'] ?? selectedSubject;
                              }
                            }

                            Navigator.pop(sheetContext);

                            if (!mounted) return;

                            final res = await ApiService.createQuiz(
                              title: title,
                              subject: selectedSubject,
                              instructor: (_user['name'] ?? _user['full_name'] ?? 'Faculty').toString(),
                              durationMinutes: duration,
                              status: selectedStatus,
                              description: descriptionController.text.trim(),
                              departmentIds: targetDeptIds,
                              courseIds: targetCourseIds,
                              branchIds: targetBranchIds,
                              sectionIds: targetSectionIds,
                              subjectIds: targetSubjectIds,
                              targetGroups: targetGroups.isNotEmpty ? targetGroups : null,
                            );

                            if (mounted) {
                              if (res['success'] == true) {
                                CustomToast.show(
                                  context,
                                  title: 'Quiz Created',
                                  message: 'Quiz "$title" created for applicable students!',
                                  type: ToastType.success,
                                );
                                _fetchFacultyData();
                              } else {
                                CustomToast.show(
                                  context,
                                  title: 'Creation Failed',
                                  message: ApiService.getErrorMessage(res, 'Could not create quiz'),
                                  type: ToastType.error,
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.add_task_rounded),
                          label: const Text('Create Quiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      Text(
                        'Add Question to "${quiz['title']}"',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mainText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: questionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Question Statement *',
                          prefixIcon: Icon(Icons.help_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Answer Options (Select correct answer) *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mainText),
                      ),
                      const SizedBox(height: 10),
                      _buildOptionField(opt1Controller, 'Option A', 0, correctIndex, (idx) => setModalState(() => correctIndex = idx)),
                      const SizedBox(height: 8),
                      _buildOptionField(opt2Controller, 'Option B', 1, correctIndex, (idx) => setModalState(() => correctIndex = idx)),
                      const SizedBox(height: 8),
                      _buildOptionField(opt3Controller, 'Option C', 2, correctIndex, (idx) => setModalState(() => correctIndex = idx)),
                      const SizedBox(height: 8),
                      _buildOptionField(opt4Controller, 'Option D', 3, correctIndex, (idx) => setModalState(() => correctIndex = idx)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final qText = questionController.text.trim();
                            final options = [
                              opt1Controller.text.trim(),
                              opt2Controller.text.trim(),
                              opt3Controller.text.trim(),
                              opt4Controller.text.trim(),
                            ].where((e) => e.isNotEmpty).toList();

                            if (qText.isEmpty || options.length < 2) {
                              CustomToast.show(
                                sheetContext,
                                message: 'Question and at least 2 options are required.',
                                type: ToastType.warning,
                              );
                              return;
                            }

                            final correctOptStr = options[correctIndex < options.length ? correctIndex : 0];

                            Navigator.pop(sheetContext);

                            if (!mounted) return;

                            final res = await ApiService.addQuestionToQuiz(
                              quizId: quiz['id'],
                              question: qText,
                              type: 'single',
                              options: options,
                              correctOption: correctOptStr,
                            );

                            if (mounted) {
                              if (res['success'] == true) {
                                CustomToast.show(
                                  context,
                                  title: 'Question Added',
                                  message: 'Question added to quiz successfully!',
                                  type: ToastType.success,
                                );
                                _fetchFacultyData();
                              } else {
                                CustomToast.show(
                                  context,
                                  title: 'Failed',
                                  message: ApiService.getErrorMessage(res, 'Could not add question'),
                                  type: ToastType.error,
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.playlist_add_check_rounded),
                          label: const Text('Add Question', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildOptionField(TextEditingController controller, String label, int index, int selectedIndex, ValueChanged<int> onSelected) {
    final isSelected = index == selectedIndex;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: IconButton(
          icon: Icon(
            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isSelected ? AppTheme.primary : Colors.grey,
          ),
          onPressed: () => onSelected(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String facultyName = _user['name'] ?? 'Faculty Member';
    final String facultyId = _user['faculty_id'] ?? 'FAC-ID';
    final String department = _user['department'] ?? 'Computer Science & Engineering';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acadova Faculty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mainText,
                  ),
                ),
                Text(
                  'Faculty Dashboard & Controls',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.mainText),
            onPressed: _fetchFacultyData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: AppTheme.mainText),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen(userData: _user)),
              );
              if (updated != null && updated is Map<String, dynamic>) {
                setState(() => _user = updated);
              }
            },
            tooltip: 'Faculty Profile',
          ),
          const SizedBox(width: 8),
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
                              onPressed: _showCreateQuizModal,
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

                    const SizedBox(height: 28),

                    // Clean Blank Dashboard Placeholder State Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.dashboard_outlined,
                              size: 48,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Faculty Dashboard',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.mainText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your dashboard is currently blank. There are no active quizzes or submissions listed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _showCreateQuizModal,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Create New Quiz', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
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

  Widget _buildFacultyMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.mainText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final bool isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
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

  Widget _buildManagedQuizzesTab() {
    if (_quizzes.isEmpty) {
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
            Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No Quizzes Created Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.mainText),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click "Create New Quiz" above to add your first assessment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _quizzes.map((quiz) {
        final int questionCount = quiz['questions_count'] ?? (quiz['questions'] is List ? (quiz['questions'] as List).length : 0);
        final String status = (quiz['status'] ?? 'active').toString();

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
                            quiz['subject'] ?? 'General',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          quiz['title'] ?? 'Quiz',
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
                      color: status == 'active'
                          ? AppTheme.success.withValues(alpha: 0.12)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: status == 'active' ? AppTheme.success : Colors.grey.shade700,
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
