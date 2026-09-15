import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'academic_profile_screen.dart';
import 'google_complete_profile_screen.dart';
import 'home_screen.dart';

enum UserRole { student, faculty }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Step 0: Role Selection, Step 1: Account Details Form
  int _currentStep = 0;
  UserRole _selectedRole = UserRole.student;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _facultyIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '764324372715-jidimhue9cakjogqgohbf4u28llck4n3.apps.googleusercontent.com',
  );

  void _handleGoogleSignup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signInSilently();
      } catch (_) {}

      googleUser ??= await _googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final GoogleSignInAccount userAccount = googleUser;
      final roleStr = _selectedRole == UserRole.student ? 'student' : 'faculty';

      final response = await ApiService.googleLogin(
        email: userAccount.email,
        name: userAccount.displayName ?? userAccount.email.split('@')[0],
        googleId: userAccount.id,
        avatar: userAccount.photoUrl,
        role: roleStr,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response['success'] == true) {
          final userData = response['data']['user'] ?? {};
          final isNewUser = response['data']['is_new'] == true;

          if (isNewUser || (userData['roll_number'] == null && userData['faculty_id'] == null)) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GoogleCompleteProfileScreen(googleUser: userAccount),
              ),
            );
            return;
          }

          final userName = userData['name'] ?? userAccount.displayName ?? 'User';
          CustomToast.show(
            context,
            title: 'Welcome to Acadova!',
            message: 'Signed in as $userName.',
            type: ToastType.success,
            customIcon: Icons.check_circle_rounded,
          );

          final isProfileIncomplete = ApiService.isProfileIncomplete(userData);

          if (isProfileIncomplete) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => AcademicProfileScreen(userData: userData, isInitialSetup: true),
              ),
              (route) => false,
            );
            return;
          }

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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GoogleCompleteProfileScreen(googleUser: userAccount),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final errStr = e.toString().toLowerCase();
        String userFriendlyMsg = 'Google Sign-In failed: ${e.toString()}';

        if (errStr.contains('missingpluginexception') ||
            errStr.contains('no implementation found for method')) {
          userFriendlyMsg = 'Google Sign-In is supported on Android & Web. Please register with your email or use Android/Web version.';
        } else if (errStr.contains('network_error') ||
            errStr.contains('socketexception') ||
            errStr.contains('failed host lookup')) {
          userFriendlyMsg = 'No Internet Connection. Please check your network and try again.';
        } else if (errStr.contains('sign_in_canceled') || errStr.contains('canceled')) {
          userFriendlyMsg = 'Sign up was cancelled.';
        }

        CustomToast.show(
          context,
          title: 'Google Sign In Error',
          message: userFriendlyMsg,
          type: ToastType.error,
          customIcon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final roleStr = _selectedRole == UserRole.student ? 'student' : 'faculty';
      final roleName =
          _selectedRole == UserRole.student ? 'Student' : 'Faculty';

      final response = await ApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: roleStr,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
        rollNumber: _selectedRole == UserRole.student
            ? _rollNumberController.text.trim()
            : null,
        facultyId: _selectedRole == UserRole.faculty
            ? _facultyIdController.text.trim()
            : null,
        department: _selectedRole == UserRole.faculty
            ? _departmentController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response['success'] == true) {
          CustomToast.show(
            context,
            title: 'Account Created!',
            message: 'Welcome to Acadova as a $roleName.',
            type: ToastType.success,
            customIcon: Icons.check_circle_rounded,
          );

          final userData = response['data']['user'] ?? {};
          final isStudent = _selectedRole == UserRole.student;

          if (isStudent) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => AcademicProfileScreen(userData: userData, isInitialSetup: true),
              ),
              (route) => false,
            );
            return;
          }

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
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _rollNumberController.dispose();
    _facultyIdController.dispose();
    _departmentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 768;

            Widget signupStepContent = AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _currentStep == 0
                  ? _buildRoleSelectionStep(isDesktop)
                  : _buildFormStep(isDesktop),
            );

            if (!isDesktop) {
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
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 28,
                          width: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.school, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Acadova Sign Up',
                        style: TextStyle(
                          color: AppTheme.mainText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  centerTitle: true,
                ),
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: signupStepContent,
                  ),
                ),
              );
            }

            // Desktop Layout: Split View with left branding panel and right signup flow
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24.0),
                constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 720),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    children: [
                      // Left Branding Panel
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(40.0),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFB45309), Color(0xFF78350F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(50),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    height: 88,
                                    width: 88,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      width: 88,
                                      height: 88,
                                      color: const Color(0xFFB45309),
                                      child: const Icon(
                                        Icons.school,
                                        size: 54,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Create Your Account',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final url = Uri.parse('https://neodyit.com');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'POWERED BY ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withAlpha(190),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const Text(
                                        'Neody IT',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amberAccent,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.amberAccent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 13,
                                        color: Colors.amberAccent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Join Acadova to take interactive quizzes, evaluate performance, and access smart learning tools.',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: Colors.white.withAlpha(225),
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  _buildBadge(Icons.verified_user_outlined, 'Verified Role'),
                                  const SizedBox(width: 12),
                                  _buildBadge(Icons.security_rounded, 'Secure Portal'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right Content Panel
                      Expanded(
                        flex: 6,
                        child: Container(
                          color: Colors.white,
                          child: Stack(
                            children: [
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 460),
                                  child: signupStepContent,
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.mainText),
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // STEP 1: Premium Role Selection View
  Widget _buildRoleSelectionStep([bool isDesktop = false]) {
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Header Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'STEP 1 OF 2',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Join as Student or Faculty',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.mainText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your role to customize your Acadova workspace experience',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Role Option 1: Student Card
          _buildRoleCard(
            role: UserRole.student,
            title: 'I am a Student',
            subtitle:
                'Take quizzes, track test scores, receive class reminders, and test your knowledge.',
            icon: Icons.school_rounded,
            gradientColors: [AppTheme.primary, AppTheme.primaryLight],
          ),
          const SizedBox(height: 20),

          // Role Option 2: Faculty Card
          _buildRoleCard(
            role: UserRole.faculty,
            title: 'I am a Faculty',
            subtitle:
                'Create quizzes, assign tests, send announcements, and evaluate student performance.',
            icon: Icons.psychology_rounded,
            gradientColors: [const Color(0xFFD97706), const Color(0xFFB45309)],
          ),
          const SizedBox(height: 40),

          // Continue Button with AnimatedSwitcher to prevent text layout shift
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: Text(
                      'Continue as ${_selectedRole == UserRole.student ? "Student" : "Faculty"}',
                      key: ValueKey(_selectedRole),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
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
          // Fixed border width 2.0 for both selected & unselected to prevent 0px layout shifting
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
            // Left Icon Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),

            // Content Title & Description
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
                          fontSize: 18,
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
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
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

  // STEP 2: Tailored Signup Form (Student / Faculty)
  Widget _buildFormStep([bool isDesktop = false]) {
    final isStudent = _selectedRole == UserRole.student;

    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selected Role Pill Tag
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
                        isStudent ? 'STUDENT ACCOUNT' : 'FACULTY ACCOUNT',
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
            const SizedBox(height: 14),

            Text(
              isStudent
                  ? 'Create Student Profile'
                  : 'Create Faculty Account',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.mainText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isStudent
                  ? 'Fill in your details and unique Roll Number to register'
                  : 'Fill in your academic details and Faculty ID to register',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 28),

            // 1. Full Name Field
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: isStudent ? 'e.g. Mayank Tiwari' : 'e.g. Dr. Aman ',
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
                if (value.trim().length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // 2. Email Address Field (Unique Check)
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'name@neodyit.in',
                prefixIcon: const Icon(Icons.email_outlined),
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
                  return 'Please enter your email address';
                }
                final emailRegex =
                    RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // 3. Roll Number (for Students) or Faculty ID (for Faculty) - Unique Check
            if (isStudent)
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
              )
            else ...[
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
            const SizedBox(height: 18),

            // 4. Password Field with Strict Validations
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                helperText:
                    'Min 6 chars with 1 uppercase & 1 digit',
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
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters long';
                }
                if (!value.contains(RegExp(r'[A-Z]'))) {
                  return 'Password must contain at least 1 uppercase letter';
                }
                if (!value.contains(RegExp(r'[0-9]'))) {
                  return 'Password must contain at least 1 number/digit';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // 5. Confirm Password Field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
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
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit Registration Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
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
                    : Text(
                        isStudent
                            ? 'Complete Student Registration'
                            : 'Complete Faculty Registration',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignup,
                icon: Image.asset(
                  'assets/images/google-icon.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Image.asset(
                    'assets/images/google_logo.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.g_mobiledata_rounded,
                            size: 26, color: Colors.redAccent),
                  ),
                ),
                label: const Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Already Have An Account Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
