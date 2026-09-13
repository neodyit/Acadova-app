import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'home_screen.dart';

class AcademicProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isInitialSetup;

  const AcademicProfileScreen({
    super.key,
    required this.userData,
    this.isInitialSetup = false,
  });

  @override
  State<AcademicProfileScreen> createState() => _AcademicProfileScreenState();
}

class _AcademicProfileScreenState extends State<AcademicProfileScreen> {
  late Map<String, dynamic> _userData;
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _colleges = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _subsections = [];

  int? _selectedUniversityId;
  int? _selectedCollegeId;
  int? _selectedDepartmentId;
  int? _selectedCourseId;
  int? _selectedBranchId;
  int? _selectedSectionId;
  int? _selectedSubsectionId;

  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
    _phoneController.text = _userData['phone'] ?? '';
    _initAcademicData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initAcademicData() async {
    setState(() {
      _isLoading = true;
    });

    final universities = await ApiService.getUniversities();
    final colleges = await ApiService.getColleges();
    final departments = await ApiService.getDepartments();
    final courses = await ApiService.getCourses();
    final branches = await ApiService.getBranches();
    final sections = await ApiService.getSections();
    final subsections = await ApiService.getSubsections();

    if (mounted) {
      setState(() {
        _universities = universities;
        _colleges = colleges;
        _departments = departments;
        _courses = courses;
        _branches = branches;
        _sections = sections;
        _subsections = subsections;

        // Set existing selection from user data if present
        _selectedUniversityId = _parseId(_userData['university_id'] ?? _userData['university']?['id']);
        _selectedCollegeId = _parseId(_userData['college_id'] ?? _userData['college']?['id']);
        _selectedDepartmentId = _parseId(_userData['department_id'] ?? _userData['department_model']?['id']);
        _selectedCourseId = _parseId(_userData['course_id'] ?? _userData['course']?['id']);
        _selectedBranchId = _parseId(_userData['branch_id'] ?? _userData['branch']?['id']);
        _selectedSectionId = _parseId(_userData['section_id'] ?? _userData['section']?['id']);
        _selectedSubsectionId = _parseId(_userData['subsection_id'] ?? _userData['subsection']?['id']);

        _isLoading = false;
      });
    }
  }

  int? _parseId(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  // Dependent cascading filters
  List<Map<String, dynamic>> get _filteredColleges {
    if (_selectedUniversityId == null) return _colleges;
    return _colleges.where((c) {
      final uId = _parseId(c['university_id']);
      return uId == null || uId == _selectedUniversityId;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredDepartments {
    if (_selectedCollegeId == null) return _departments;
    return _departments.where((d) {
      final cId = _parseId(d['college_id']);
      return cId == null || cId == _selectedCollegeId;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCourses {
    if (_selectedDepartmentId == null) return _courses;
    return _courses.where((cr) {
      final dId = _parseId(cr['department_id']);
      return dId == null || dId == _selectedDepartmentId;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredBranches {
    if (_selectedCourseId == null) return _branches;
    return _branches.where((b) {
      final crId = _parseId(b['course_id']);
      return crId == null || crId == _selectedCourseId;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSections {
    if (_selectedBranchId == null) return _sections;
    return _sections.where((s) {
      final bId = _parseId(s['branch_id']);
      return bId == null || bId == _selectedBranchId;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSubsections {
    if (_selectedSectionId == null) return _subsections;
    return _subsections.where((sub) {
      final sId = _parseId(sub['section_id']);
      return sId == null || sId == _selectedSectionId;
    }).toList();
  }

  Future<void> _handleSaveAcademicProfile() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      CustomToast.show(context, title: 'Phone Required', message: 'Please enter your phone number.', type: ToastType.warning);
      return;
    }

    if (_selectedUniversityId == null || _selectedCollegeId == null || _selectedDepartmentId == null || _selectedCourseId == null || _selectedBranchId == null || _selectedSectionId == null || _selectedSubsectionId == null) {
      CustomToast.show(context, title: 'Incomplete Selection', message: 'Please select options for all academic fields.', type: ToastType.warning);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final res = await ApiService.updateAcademicProfile(
      phone: phone,
      universityId: _selectedUniversityId,
      collegeId: _selectedCollegeId,
      departmentId: _selectedDepartmentId,
      courseId: _selectedCourseId,
      branchId: _selectedBranchId,
      sectionId: _selectedSectionId,
      subsectionId: _selectedSubsectionId,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (res['success'] == true) {
        CustomToast.show(
          context,
          title: 'Academic Details Saved',
          message: 'Your academic structure details have been updated.',
          type: ToastType.success,
        );

        final updatedUser = res['data']['user'] ?? _userData;

        if (widget.isInitialSetup) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeScreen(userData: Map<String, dynamic>.from(updatedUser)),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pop(updatedUser);
        }
      } else {
        CustomToast.show(
          context,
          title: 'Update Failed',
          message: ApiService.getErrorMessage(res, 'Could not save academic profile.'),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: widget.isInitialSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.mainText),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Academic Profile',
          style: TextStyle(color: AppTheme.mainText, fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Academic Structure',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select your University, College, Department, Course, Branch, Section, and Subsection from the dropdown lists.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 0. Phone Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phone Number *',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mainText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Enter mobile number',
                            prefixIcon: Icon(Icons.phone_android_rounded, color: AppTheme.primary, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. University Dropdown
                  _buildDropdownTile(
                    label: 'University',
                    icon: Icons.account_balance_rounded,
                    value: _selectedUniversityId,
                    items: _universities,
                    onChanged: (val) {
                      setState(() {
                        _selectedUniversityId = val;
                        _selectedCollegeId = null;
                        _selectedDepartmentId = null;
                        _selectedCourseId = null;
                        _selectedBranchId = null;
                        _selectedSectionId = null;
                        _selectedSubsectionId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. College Dropdown
                  _buildDropdownTile(
                    label: 'College / Institute',
                    icon: Icons.apartment_rounded,
                    value: _selectedCollegeId,
                    items: _filteredColleges,
                    onChanged: (val) {
                      setState(() {
                        _selectedCollegeId = val;
                        _selectedDepartmentId = null;
                        _selectedCourseId = null;
                        _selectedBranchId = null;
                        _selectedSectionId = null;
                        _selectedSubsectionId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. Department Dropdown
                  _buildDropdownTile(
                    label: 'Department',
                    icon: Icons.business_center_rounded,
                    value: _selectedDepartmentId,
                    items: _filteredDepartments,
                    onChanged: (val) {
                      setState(() {
                        _selectedDepartmentId = val;
                        _selectedCourseId = null;
                        _selectedBranchId = null;
                        _selectedSectionId = null;
                        _selectedSubsectionId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. Course Dropdown
                  _buildDropdownTile(
                    label: 'Course / Degree',
                    icon: Icons.school_rounded,
                    value: _selectedCourseId,
                    items: _filteredCourses,
                    onChanged: (val) {
                      setState(() {
                        _selectedCourseId = val;
                        _selectedBranchId = null;
                        _selectedSectionId = null;
                        _selectedSubsectionId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 5. Branch Dropdown
                  _buildDropdownTile(
                    label: 'Branch / Specialization',
                    icon: Icons.alt_route_rounded,
                    value: _selectedBranchId,
                    items: _filteredBranches,
                    onChanged: (val) {
                      setState(() {
                        _selectedBranchId = val;
                        _selectedSectionId = null;
                        _selectedSubsectionId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 6. Section Dropdown
                  _buildDropdownTile(
                    label: 'Section',
                    icon: Icons.class_rounded,
                    value: _selectedSectionId,
                    items: _filteredSections,
                    onChanged: (val) {
                      setState(() {
                        _selectedSectionId = val;
                        _selectedSubsectionId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 7. Subsection Dropdown
                  _buildDropdownTile(
                    label: 'Subsection / Batch',
                    icon: Icons.groups_rounded,
                    value: _selectedSubsectionId,
                    items: _filteredSubsections,
                    onChanged: (val) {
                      setState(() {
                        _selectedSubsectionId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSaveAcademicProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              widget.isInitialSetup ? 'Continue to Dashboard' : 'Save Academic Details',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdownTile({
    required String label,
    required IconData icon,
    required int? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int?> onChanged,
  }) {
    // Ensure value exists in items list
    final bool valueExists = items.any((i) => _parseId(i['id']) == value);
    final int? selectedValue = valueExists ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.mainText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedValue,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(icon, color: AppTheme.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Select $label',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
              items: items.map((item) {
                final id = _parseId(item['id'])!;
                final name = item['name']?.toString() ?? 'Item #$id';
                return DropdownMenuItem<int>(
                  value: id,
                  child: Row(
                    children: [
                      Icon(icon, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.mainText,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
