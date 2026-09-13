import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'home_screen.dart';

enum UserRole { student, faculty }

class GoogleCompleteProfileScreen extends StatefulWidget {
  final GoogleSignInAccount googleUser;

  const GoogleCompleteProfileScreen({
    super.key,
    required this.googleUser,
  });

  @override
  State<GoogleCompleteProfileScreen> createState() =>
      _GoogleCompleteProfileScreenState();
}

class _GoogleCompleteProfileScreenState
    extends State<GoogleCompleteProfileScreen> {
  int _currentStep = 0; // Step 0: Select Role, Step 1: Extra Details
  UserRole _selectedRole = UserRole.student;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _rollNumberController = TextEditingController();
  final _facultyIdController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.googleUser.displayName ??
            widget.googleUser.email.split('@')[0]);
    _emailController = TextEditingController(text: widget.googleUser.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _rollNumberController.dispose();
    _facultyIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _handleCompleteProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final roleStr = _selectedRole == UserRole.student ? 'student' : 'faculty';
      final roleName =
          _selectedRole == UserRole.student ? 'Student' : 'Faculty';

      final response = await ApiService.googleLogin(
        email: widget.googleUser.email,
        name: _nameController.text.trim(),
        googleId: widget.googleUser.id,
        avatar: widget.googleUser.photoUrl,
        role: roleStr,
        rollNumber: _selectedRole == UserRole.student
            ? _rollNumberController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response['success'] == true) {
          CustomToast.show(
            context,
            title: 'Profile Complete!',
            message: 'Welcome to Acadova as a $roleName.',
            type: ToastType.success,
            customIcon: Icons.check_circle_rounded,
          );

          final userData = response['data']['user'] ?? {};

          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  HomeScreen(userData: userData),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
            (route) => false,
          );
        } else {
          Map<String, dynamic>? errors;
          if (response['errors'] is Map) {
            errors = Map<String, dynamic>.from(response['errors']);
          }
          String errorMsg = response['message'] ?? 'Registration failed';
          if (errors != null && errors.isNotEmpty) {
            final firstErrorKey = errors.keys.first;
            final firstErrorList = errors[firstErrorKey] as List?;
            if (firstErrorList != null && firstErrorList.isNotEmpty) {
              errorMsg = firstErrorList.first.toString();
            }
          }

          CustomToast.show(
            context,
            title: 'Registration Failed',
            message: errorMsg,
            type: ToastType.error,
            customIcon: Icons.error_outline_rounded,
          );
        }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.mainText),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep = 0;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'Complete Profile',
          style: TextStyle(
            color: AppTheme.mainText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _currentStep == 0
              ? _buildRoleSelectionStep()
              : _buildFormStep(),
        ),
      ),
    );
  }

  // STEP 1: Role Selection
  Widget _buildRoleSelectionStep() {
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Profile Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  backgroundImage: widget.googleUser.photoUrl != null
                      ? NetworkImage(widget.googleUser.photoUrl!)
                      : null,
                  child: widget.googleUser.photoUrl == null
                      ? const Icon(Icons.person, size: 36, color: AppTheme.primary)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.googleUser.displayName ?? 'Google User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mainText,
                  ),
                ),
                Text(
                  widget.googleUser.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Almost there! Choose your role to complete your Acadova account setup.',
                    style: TextStyle(fontSize: 13, color: AppTheme.mainText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Role Option 1: Student Card
          _buildRoleCard(
            role: UserRole.student,
            title: 'I am a Student',
            subtitle:
                'Take quizzes, track test scores, receive class reminders, and test your knowledge.',
            icon: Icons.school_rounded,
            gradientColors: [AppTheme.primary, AppTheme.primaryLight],
          ),
          const SizedBox(height: 16),

          // Role Option 2: Faculty Card
          _buildRoleCard(
            role: UserRole.faculty,
            title: 'I am a Faculty',
            subtitle:
                'Create quizzes, assign tests, send announcements, and evaluate student performance.',
            icon: Icons.psychology_rounded,
            gradientColors: [const Color(0xFFD97706), const Color(0xFFB45309)],
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue as ${_selectedRole == UserRole.student ? "Student" : "Faculty"}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? gradientColors[0].withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? gradientColors[0] : Colors.grey.shade200,
            width: 2.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? gradientColors[0]
                              : const Color(0xFF2D3436),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: gradientColors[0],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 2: Details Form
  Widget _buildFormStep() {
    final isStudent = _selectedRole == UserRole.student;

    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selected Role Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isStudent
                            ? Icons.school_rounded
                            : Icons.psychology_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isStudent ? 'STUDENT PROFILE' : 'FACULTY PROFILE',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                    });
                  },
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Change Role', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              isStudent ? 'Academic Information' : 'Faculty Information',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.mainText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isStudent
                  ? 'Enter your Roll Number to complete registration'
                  : 'Enter your Faculty ID and Department to complete registration',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),

            // Name Field (Prefilled from Google)
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Email Field (Read Only from Google)
            TextFormField(
              controller: _emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Google Email',
                prefixIcon: const Icon(Icons.email_outlined),
                suffixIcon: const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Specific details based on role
            if (isStudent) ...[
              TextFormField(
                controller: _rollNumberController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Roll Number (Unique)',
                  hintText: 'e.g. 2546167',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  helperText: 'Must be unique to your institution',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your Roll Number';
                  }
                  if (value.trim().length < 3) {
                    return 'Roll Number must be at least 3 characters';
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _facultyIdController,
                decoration: InputDecoration(
                  labelText: 'Faculty ID',
                  hintText: 'e.g. J1234',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your Faculty ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _departmentController,
                decoration: InputDecoration(
                  labelText: 'Department',
                  hintText: 'e.g. Computer Science',
                  prefixIcon: const Icon(Icons.menu_book_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your Department';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCompleteProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Complete & Launch Acadova',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
