import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'academic_profile_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({
    super.key,
    required this.userData,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _user;
  List<Map<String, dynamic>> _userAttempts = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _rollController;
  late TextEditingController _deptController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.userData);
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _rollController = TextEditingController();
    _deptController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _syncControllers();
    _fetchProfileData();
  }

  void _syncControllers() {
    _nameController.text = _user['name'] ?? '';
    _emailController.text = _user['email'] ?? '';
    _rollController.text = _user['roll_number'] ?? _user['faculty_id'] ?? '';
    _deptController.text = _user['department'] ?? '';
    _phoneController.text = _user['phone'] ?? '';
    _bioController.text = _user['bio'] ?? '';
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch fresh user profile from DB (/api/me)
      final profileResp = await ApiService.getProfile();
      if (profileResp['success'] == true && profileResp['data'] != null) {
        final freshData = profileResp['data'];
        final freshUser = (freshData is Map && freshData.containsKey('user'))
            ? freshData['user']
            : freshData;

        if (freshUser is Map<String, dynamic>) {
          _user = Map<String, dynamic>.from(freshUser);
          _syncControllers();
        }
      }

      // 2. Fetch live quiz attempts from DB (/api/attempts)
      final attemptsData = await ApiService.getUserAttempts();
      _userAttempts = attemptsData;
    } catch (e) {
      debugPrint('Profile data fetch error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _rollController.dispose();
    _deptController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    final newRoll = _rollController.text.trim();
    final newDept = _deptController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newBio = _bioController.text.trim();

    if (newName.isEmpty) {
      CustomToast.show(context, message: 'Name cannot be empty', type: ToastType.warning);
      return;
    }

    setState(() => _isSaving = true);

    final userRole = (_user['role'] ?? 'student').toString().toLowerCase();

    final res = await ApiService.updateProfile(
      name: newName,
      phone: newPhone,
      rollNumber: userRole == 'student' ? newRoll : null,
      facultyId: userRole == 'faculty' ? newRoll : null,
      department: newDept,
      bio: newBio,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });

      if (res['success'] == true) {
        if (res['data'] != null && res['data']['user'] != null) {
          setState(() {
            _user = Map<String, dynamic>.from(res['data']['user']);
            _syncControllers();
          });
        }
        CustomToast.show(
          context,
          message: 'Profile updated in database!',
          type: ToastType.success,
        );
      } else {
        CustomToast.show(
          context,
          title: 'Update Failed',
          message: ApiService.getErrorMessage(res, 'Failed to update profile'),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _pickAndUploadAvatar({bool useCamera = false}) async {
    try {
      List<int>? bytes;
      String fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (useCamera) {
        // Fallback to ImagePicker for camera capture if selected
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (pickedFile == null) return;
        bytes = await pickedFile.readAsBytes();
        fileName = pickedFile.name;
      } else {
        // Use FilePicker API (Play Store compliant Photo Picker / SAF)
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        if (file.name.isNotEmpty) {
          fileName = file.name;
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          CustomToast.show(
            context,
            message: 'Unable to read selected image file.',
            type: ToastType.error,
          );
        }
        return;
      }

      setState(() => _isSaving = true);

      final uploadRes = await ApiService.uploadMedia(
        fileBytes: bytes,
        fileName: fileName,
        folder: 'avatars',
      );

      if (uploadRes['success'] == true && uploadRes['data'] != null) {
        final avatarUrl = uploadRes['data']['url'];

        // Save updated avatar URL to backend database
        final updateRes = await ApiService.updateProfile(
          name: _user['name'] ?? '',
          phone: _user['phone'],
          rollNumber: _user['roll_number'],
          facultyId: _user['faculty_id'],
          department: _user['department'],
          bio: _user['bio'],
          avatar: avatarUrl,
        );

        if (updateRes['success'] == true && updateRes['data'] != null && updateRes['data']['user'] != null) {
          _user = Map<String, dynamic>.from(updateRes['data']['user']);
        } else {
          _user['avatar'] = avatarUrl;
        }

        if (ApiService.authToken != null) {
          await ApiService.saveSession(ApiService.authToken!, _user);
        }

        if (mounted) {
          CustomToast.show(
            context,
            message: 'Profile picture updated successfully!',
            type: ToastType.success,
          );
        }
      } else {
        if (mounted) {
          CustomToast.show(
            context,
            message: uploadRes['message'] ?? 'Failed to upload profile picture',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Error picking image: $e. Rebuild app if native channel error occurs.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAvatarPickerModal() {
    showModalBottomSheet(
      context: context,
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
              const Text(
                'Update Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF6C5CE7)),
                ),
                title: const Text('Choose from Gallery (File Picker)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Play Store compliant system picker', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(useCamera: false);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00B894)),
                ),
                title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(useCamera: true);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Calculate live statistics dynamically from DB attempts
  int get _quizzesTakenCount => _userAttempts.length;

  int get _avgAccuracyPercent {
    if (_userAttempts.isEmpty) return 0;
    int totalEarned = 0;
    int totalPossible = 0;

    for (var att in _userAttempts) {
      totalEarned += ((att['score'] ?? 0) as num).toInt();
      totalPossible += ((att['total_questions'] ?? 1) as num).toInt();
    }

    if (totalPossible == 0) return 0;
    return ((totalEarned / totalPossible) * 100).round();
  }

  int get _totalScorePoints {
    int total = 0;
    for (var att in _userAttempts) {
      total += ((att['score'] ?? 0) as num).toInt();
    }
    return total;
  }

  String _formatMemberSince(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Active Member';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return 'Active Member';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[parsed.month - 1]} ${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final String name = _user['name'] ?? 'User';
    final String email = _user['email'] ?? '';
    final String role = (_user['role'] ?? 'Student').toString().toUpperCase();
    final String rollOrFaculty = _user['roll_number'] ?? _user['faculty_id'] ?? 'Not Assigned';
    final String phone = _user['phone'] ?? 'Not Specified';
    final String bio = _user['bio'] ?? '';
    final String memberSince = _formatMemberSince(_user['created_at']?.toString());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.mainText, size: 20),
          onPressed: () => Navigator.pop(context, _user),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppTheme.mainText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
            )
          else
            IconButton(
              icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded, color: AppTheme.primary),
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.mainText),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(userData: _user),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _fetchProfileData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Profile Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
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
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _showAvatarPickerModal,
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white,
                            child: Builder(
                              builder: (context) {
                                final avatarUrl = ApiService.formatMediaUrl(_user['avatar']?.toString());
                                return CircleAvatar(
                                  radius: 41,
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                  child: avatarUrl == null
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showAvatarPickerModal,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$role  •  $rollOrFaculty',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Live Backend Statistics Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFFFA502),
                      value: '$_quizzesTakenCount',
                      label: 'Quizzes Taken',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.military_tech_rounded,
                      color: const Color(0xFF2ED573),
                      value: '$_avgAccuracyPercent%',
                      label: 'Avg Accuracy',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.stars_rounded,
                      color: AppTheme.primary,
                      value: '$_totalScorePoints',
                      label: 'Score Points',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Personal Information Card (Dynamic DB Fields)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Account Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        if (_isEditing)
                          const Text(
                            'Editing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6C5CE7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildProfileField(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      value: name,
                      controller: _nameController,
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    _buildProfileField(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: email,
                      controller: null, // Email locked for security
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    _buildProfileField(
                      icon: Icons.badge_outlined,
                      label: role == 'FACULTY' ? 'Faculty ID' : 'Roll Number',
                      value: rollOrFaculty,
                      controller: _rollController,
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    _buildProfileField(
                      icon: Icons.phone_android_rounded,
                      label: 'Phone Number',
                      value: phone,
                      controller: _phoneController,
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    _buildProfileField(
                      icon: Icons.info_outline_rounded,
                      label: 'Bio / Note',
                      value: bio.isEmpty ? 'No bio added yet' : bio,
                      controller: _bioController,
                      isEditing: _isEditing,
                    ),
                     const SizedBox(height: 16),
                    _buildProfileField(
                      icon: Icons.calendar_today_rounded,
                      label: 'Member Since',
                      value: memberSince,
                      controller: null,
                      isEditing: _isEditing,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Academic Structure Information Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.account_balance_rounded, color: AppTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Academic Structure',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final updatedUser = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AcademicProfileScreen(userData: _user),
                              ),
                            );
                            if (updatedUser != null && updatedUser is Map<String, dynamic>) {
                              setState(() {
                                _user = updatedUser;
                                _syncControllers();
                              });
                            }
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.primary),
                          label: const Text(
                            'Edit',
                            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildAcademicDisplayRow(
                      icon: Icons.account_balance_rounded,
                      label: 'University',
                      value: _user['university']?['name'] ?? 'Not Selected',
                    ),
                    const SizedBox(height: 12),
                    _buildAcademicDisplayRow(
                      icon: Icons.apartment_rounded,
                      label: 'College / Institute',
                      value: _user['college']?['name'] ?? 'Not Selected',
                    ),
                    const SizedBox(height: 12),
                    _buildAcademicDisplayRow(
                      icon: Icons.business_center_rounded,
                      label: 'Department',
                      value: _user['department_model']?['name'] ?? _user['department'] ?? 'Not Selected',
                    ),
                    const SizedBox(height: 12),
                    _buildAcademicDisplayRow(
                      icon: Icons.school_rounded,
                      label: 'Course / Degree',
                      value: _user['course']?['name'] ?? 'Not Selected',
                    ),
                    const SizedBox(height: 12),
                    _buildAcademicDisplayRow(
                      icon: Icons.alt_route_rounded,
                      label: 'Branch / Specialization',
                      value: _user['branch']?['name'] ?? 'Not Selected',
                    ),
                    const SizedBox(height: 12),
                    _buildAcademicDisplayRow(
                      icon: Icons.class_rounded,
                      label: 'Section',
                      value: _user['section']?['name'] ?? 'Not Selected',
                    ),
                    const SizedBox(height: 12),
                    _buildAcademicDisplayRow(
                      icon: Icons.groups_rounded,
                      label: 'Subsection / Batch',
                      value: _user['subsection']?['name'] ?? 'Not Selected',
                    ),
                    if ((_user['role'] ?? 'student').toString().toLowerCase() != 'faculty') ...[
                      const SizedBox(height: 12),
                      _buildAcademicDisplayRow(
                        icon: Icons.calendar_view_week_rounded,
                        label: 'Semester',
                        value: _user['semester'] != null && _user['semester'].toString().isNotEmpty
                            ? 'Semester ${_user['semester']}'
                            : 'Not Selected',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions Card
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_outlined, color: Color(0xFF6C5CE7)),
                        title: const Text('App Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingsScreen(userData: _user),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00B894)),
                        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () => _showChangePasswordModal(),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        title: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        onTap: () async {
                          await ApiService.clearSession();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required String value,
    TextEditingController? controller,
    required bool isEditing,
  }) {
    final bool canEditThisField = isEditing && controller != null;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF6C5CE7), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              canEditThisField
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
                      ),
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                          border: InputBorder.none,
                        ),
                      ),
                    )
                  : Text(
                      value.isNotEmpty ? value : 'Not specified',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isEditing && controller == null ? Colors.grey.shade500 : const Color(0xFF2D3436),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  void _showChangePasswordModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _ChangePasswordBottomSheet();
      },
    );
  }

  Widget _buildAcademicDisplayRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 180, 83, 9).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mainText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordBottomSheet extends StatefulWidget {
  const _ChangePasswordBottomSheet();

  @override
  State<_ChangePasswordBottomSheet> createState() => _ChangePasswordBottomSheetState();
}

class _ChangePasswordBottomSheetState extends State<_ChangePasswordBottomSheet> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final pass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() {
      _hasMinLength = pass.length >= 6;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(pass);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(pass);
      _hasNumber = RegExp(r'[0-9]').hasMatch(pass);

      const String specialChars = r'!@#$%^&*(),.?":{}|<>_-';
      _hasSpecial = pass.split('').any((char) => specialChars.contains(char));

      _passwordsMatch = pass.isNotEmpty && pass == confirm;
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecial) {
      CustomToast.show(
        context,
        title: 'Weak Password',
        message: 'Please fulfill all password requirements below.',
        type: ToastType.warning,
      );
      return;
    }

    if (!_passwordsMatch) {
      CustomToast.show(
        context,
        title: 'Password Mismatch',
        message: 'Confirm password does not match new password.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await ApiService.changePassword(
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        Navigator.pop(context);
        CustomToast.show(
          context,
          title: 'Success!',
          message: 'Password updated successfully!',
          type: ToastType.success,
          customIcon: Icons.check_circle_rounded,
        );
      } else {
        CustomToast.show(
          context,
          title: 'Update Failed',
          message: res['message'] ?? 'Failed to update password',
          type: ToastType.error,
        );
      }
    }
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isMet ? const Color(0xFF166534) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isMet ? const Color(0xFF166534) : const Color(0xFFA8A29E),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 10,
              color: isMet ? Colors.white : Colors.transparent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
                color: isMet ? const Color(0xFF166534) : const Color(0xFF57534E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 223, 74, 23).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: const Color.fromARGB(255, 223, 74, 23),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // New Password Field
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: const Color.fromARGB(255, 223, 74, 23)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF666666),
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: const Color.fromARGB(255, 223, 74, 23), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Confirm Password Field
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: const Color.fromARGB(255, 223, 74, 23)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF666666),
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color:const Color.fromARGB(255, 223, 74, 23), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Requirements checklist card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Password Requirements:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildRequirementItem('At least 6 characters long', _hasMinLength),
                    _buildRequirementItem('At least 1 uppercase letter (A-Z)', _hasUppercase),
                    _buildRequirementItem('At least 1 lowercase letter (a-z)', _hasLowercase),
                    _buildRequirementItem('At least 1 number (0-9)', _hasNumber),
                    _buildRequirementItem('At least 1 special character (!@#\$%^&*)', _hasSpecial),
                    _buildRequirementItem('Confirm password matches', _passwordsMatch),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleUpdatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 223, 74, 23),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
