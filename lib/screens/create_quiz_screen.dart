import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'manage_questions_screen.dart';

class CreateQuizScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final List<Map<String, dynamic>> allocations;

  const CreateQuizScreen({
    super.key,
    required this.userData,
    required this.allocations,
  });

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;

  String _selectedStatus = 'active';
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  Set<String> _selectedBatches = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _durationController = TextEditingController(text: '15');

    // Pre-select all allocations by default
    _selectedBatches = widget.allocations.map((a) => _formatBatchLabel(a)).toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
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

  // Convert selected DateTime and TimeOfDay into ISO 8601 string for backend matching (UTC / GMT sync)
  String? _formatIsoDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return dt.toUtc().toIso8601String();
  }

  // Display date and time in 12-hour AM/PM format
  String _formatDisplayDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return 'Select Date & Time';
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    
    final day = dt.day.toString().padLeft(2, '0');
    final month = _getMonthName(dt.month);
    final year = dt.year;

    final hourNum = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final hour = hourNum.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return '$day $month $year, $hour:$minute $period';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.mainText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final initialTime = isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? _startTime ?? TimeOfDay.now());

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.mainText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = pickedDate;
        _startTime = pickedTime;
      } else {
        _endDate = pickedDate;
        _endTime = pickedTime;
      }
    });
  }

  Future<void> _submitQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final duration = int.tryParse(_durationController.text.trim()) ?? 15;

    if (_selectedStatus == 'upcoming' && (_startDate == null || _startTime == null)) {
      CustomToast.show(
        context,
        message: 'Please select Quiz Start Date & Time for upcoming status',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    List<dynamic> targetSectionIds = ['all'];
    List<dynamic> targetDeptIds = ['all'];
    List<dynamic> targetCourseIds = ['all'];
    List<dynamic> targetBranchIds = ['all'];
    List<dynamic> targetSubjectIds = ['all'];
    List<Map<String, dynamic>> targetGroups = [];
    String selectedSubject = widget.userData['department'] ?? 'Computer Science';

    if (_selectedBatches.isNotEmpty) {
      final matchingAllocs = widget.allocations.where((a) {
        return _selectedBatches.contains(_formatBatchLabel(a));
      }).toList();

      targetSectionIds = matchingAllocs.map((a) => a['section_id']).where((id) => id != null).toList();
      targetDeptIds = matchingAllocs.map((a) => a['department_id']).where((id) => id != null).toList();
      targetCourseIds = matchingAllocs.map((a) => a['course_id']).where((id) => id != null).toList();
      targetBranchIds = matchingAllocs.map((a) => a['branch_id']).where((id) => id != null).toList();
      targetSubjectIds = matchingAllocs.map((a) => a['subject_id'] ?? a['subject_name']).where((id) => id != null).toList();

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

    final startIso = _formatIsoDateTime(_startDate, _startTime);
    final endIso = _formatIsoDateTime(_endDate, _endTime);

    final res = await ApiService.createQuiz(
      title: title,
      subject: selectedSubject,
      instructor: (widget.userData['name'] ?? widget.userData['full_name'] ?? 'Faculty').toString(),
      durationMinutes: duration,
      status: _selectedStatus,
      description: description,
      scheduledAt: startIso,
      startsAt: startIso,
      endsAt: endIso,
      departmentIds: targetDeptIds,
      courseIds: targetCourseIds,
      branchIds: targetBranchIds,
      sectionIds: targetSectionIds,
      subjectIds: targetSubjectIds,
      targetGroups: targetGroups.isNotEmpty ? targetGroups : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      CustomToast.show(
        context,
        title: 'Quiz Created',
        message: 'Quiz "$title" created successfully! Add your questions below.',
        type: ToastType.success,
      );

      final createdQuiz = (res['data'] is Map && res['data']['id'] != null)
          ? res['data']
          : {'id': res['quiz_id'], 'title': title, 'subject': selectedSubject, 'duration_minutes': duration};

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ManageQuestionsScreen(quiz: Map<String, dynamic>.from(createdQuiz)),
        ),
      );
    } else {
      CustomToast.show(
        context,
        title: 'Creation Failed',
        message: ApiService.getErrorMessage(res, 'Could not create quiz'),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllBatchesSelected = widget.allocations.isNotEmpty &&
        _selectedBatches.length == widget.allocations.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.mainText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create New Quiz',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppTheme.mainText,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Quiz Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Quiz Title *',
                  prefixIcon: Icon(Icons.quiz_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter quiz title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2. Description / Instructions
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description / Instructions',
                  prefixIcon: Icon(Icons.description_rounded),
                  hintText: 'Enter quiz rules, guidelines, or instructions...',
                ),
              ),
              const SizedBox(height: 20),

              // 3. Target Batches (Allocated Batches Checkboxes)
              if (widget.allocations.isNotEmpty) ...[
                const Text(
                  'Target Batches *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.mainText),
                ),
                const SizedBox(height: 8),
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
                        CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          title: const Text(
                            'Select All Batches',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.primary),
                          ),
                          value: isAllBatchesSelected,
                          activeColor: AppTheme.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedBatches = widget.allocations.map((a) => _formatBatchLabel(a)).toSet();
                              } else {
                                _selectedBatches.clear();
                              }
                            });
                          },
                        ),
                        const Divider(height: 1),
                        ...widget.allocations.map((alloc) {
                          final batchLabel = _formatBatchLabel(alloc);
                          final isSelected = _selectedBatches.contains(batchLabel);

                          return CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                            title: Text(
                              batchLabel,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            value: isSelected,
                            activeColor: AppTheme.primary,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedBatches.add(batchLabel);
                                } else {
                                  _selectedBatches.remove(batchLabel);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 4. Duration & Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (Mins) *',
                        prefixIcon: Icon(Icons.timer_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter duration';
                        if (int.tryParse(val.trim()) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status *',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active (Live)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'upcoming', child: Text('Upcoming', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Quiz Start & End Date Time Picker Section
              const Text(
                'Schedule Date & Time (UTC Synced)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.mainText),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select start & end date/time in 12-hour AM/PM mode. Formatted automatically for server GMT sync.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),

              // Start Date Time Selector Tile
              InkWell(
                onTap: () => _pickDateTime(isStart: true),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Date & Time',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDisplayDateTime(_startDate, _startTime),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: (_startDate != null && _startTime != null) ? AppTheme.mainText : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // End Date Time Selector Tile
              InkWell(
                onTap: () => _pickDateTime(isStart: false),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.stop_circle_outlined, color: Colors.orange, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Date & Time (Optional)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDisplayDateTime(_endDate, _endTime),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: (_endDate != null && _endTime != null) ? AppTheme.mainText : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_rounded, color: Colors.orange, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitQuiz,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_task_rounded),
                  label: Text(
                    _isSubmitting ? 'Creating Quiz...' : 'Create Quiz',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
