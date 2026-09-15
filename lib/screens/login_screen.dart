import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';
import 'academic_profile_screen.dart';
import 'forgot_password_screen.dart';
import 'google_complete_profile_screen.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;



  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final response = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response['success'] == true) {
          final userName = response['data']['user']['name'] ?? 'User';
          CustomToast.show(
            context,
            title: 'Welcome Back!',
            message: 'Signed in as $userName.',
            type: ToastType.success,
            customIcon: Icons.check_circle_rounded,
          );

          final userData = response['data']['user'] ?? {};
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
          CustomToast.show(
            context,
            title: 'Sign In Failed',
            message: response['message'] ?? 'Invalid credentials.',
            type: ToastType.error,
            customIcon: Icons.error_outline_rounded,
          );
        }
      }
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '764324372715-jidimhue9cakjogqgohbf4u28llck4n3.apps.googleusercontent.com',
  );

  void _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try silent sign-in first, but catch silently if user needs to interactively sign in
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signInSilently();
      } catch (silentError) {
        print('Silent sign in unavailable, falling back to interactive sign-in: $silentError');
      }

      googleUser ??= await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the Google sign in dialog
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final GoogleSignInAccount userAccount = googleUser;

      // First attempt to sign in with existing Google account
      final response = await ApiService.googleLogin(
        email: userAccount.email,
        name: userAccount.displayName ?? userAccount.email.split('@')[0],
        googleId: userAccount.id,
        avatar: userAccount.photoUrl,
        // Do not force role so backend detects if user already exists
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response['success'] == true) {
          final userData = response['data']['user'] ?? {};
          final isNewUser = response['data']['is_new'] == true;

          // If new user or profile incomplete, redirect to GoogleCompleteProfileScreen
          if (isNewUser || userData['roll_number'] == null && userData['faculty_id'] == null) {
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
            title: 'Welcome Back!',
            message: 'Signed in with Google as $userName.',
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
          // If login fails, navigate to profile completion
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GoogleCompleteProfileScreen(googleUser: userAccount),
            ),
          );
        }
      }
    } catch (e) {
      print('Google Sign-In Error Details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final errStr = e.toString().toLowerCase();
        String userFriendlyMsg = 'Google Sign-In failed: ${e.toString()}';

        if (errStr.contains('missingpluginexception') ||
            errStr.contains('no implementation found for method')) {
          // On Windows desktop, launch web browser OAuth flow directly
          final webLoginUrl = Uri.parse('https://acadova.neodyit.com/login');
          if (await canLaunchUrl(webLoginUrl)) {
            await launchUrl(webLoginUrl, mode: LaunchMode.externalApplication);
            CustomToast.show(
              context,
              title: 'Opening Web Browser',
              message: 'Opened Acadova web sign-in portal in your browser.',
              type: ToastType.info,
              customIcon: Icons.open_in_browser_rounded,
            );
          } else {
            userFriendlyMsg = 'Unable to launch web browser. Please visit https://acadova.neodyit.com/login';
          }
          return;
        } else if (errStr.contains('network_error') ||
            errStr.contains('socketexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('no address associated with hostname')) {
          userFriendlyMsg = 'No Internet Connection. Please connect to the internet and try again.';
        } else if (errStr.contains('apiexception: 7')) {
          userFriendlyMsg = 'Network / API Exception (7): Unable to connect to Google Auth servers or backend host.';
        } else if (errStr.contains('sign_in_failed') || errStr.contains('apiexception: 10') || errStr.contains('developer_error')) {
          userFriendlyMsg = 'Google Sign-In configuration error. Please check SHA-1 / OAuth credentials.';
        } else if (errStr.contains('sign_in_canceled') || errStr.contains('canceled')) {
          userFriendlyMsg = 'Sign in was cancelled.';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECDD),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 768;

            Widget loginFormContent = SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isDesktop) ...[
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB45309).withValues(alpha: 0.15),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.school,
                                size: 50,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      'Welcome Back',
                      textAlign: isDesktop ? TextAlign.start : TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 26 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111111),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to access your Acadova workspace',
                      textAlign: isDesktop ? TextAlign.start : TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Email Input Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'student@neodyit.in',
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFB45309)),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5D5C0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFFB45309), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Input Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFB45309)),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF666666),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5D5C0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFFB45309), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 4) {
                          return 'Password must be at least 4 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ForgotPasswordScreen(
                                initialEmail: _emailController.text.trim(),
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Login Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB45309),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (!isDesktop && ApiService.isGoogleAuthEnabledForCurrentPlatform()) ...[
                      const SizedBox(height: 20),
                      // Divider "OR"
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
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
                      const SizedBox(height: 18),

                      // Google Login Button
                      SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleLogin,
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
                    ],
                    const SizedBox(height: 20),

                    // Sign Up Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SignupScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Color(0xFF6C5CE7),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Bottom Links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final Uri url = Uri.parse('https://acadova.neodyit.com/privacy-policy');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Privacy Policy', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                        Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                        TextButton(
                          onPressed: () async {
                            final Uri url = Uri.parse('https://acadova.neodyit.com/terms-of-service');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Terms of Service', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                        Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                        TextButton(
                          onPressed: () async {
                            final Uri url = Uri.parse('https://acadova.neodyit.com/help-center');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Help Center', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: InkWell(
                        onTap: () async {
                          final url = Uri.parse('https://neodyit.com');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            'Powered by Neody IT',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB45309),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (!isDesktop) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: loginFormContent,
                ),
              );
            }

            // Desktop Layout: Split View with Branding panel on left and login form on right
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24.0),
                constraints: const BoxConstraints(maxWidth: 960, maxHeight: 640),
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
                      // Left Branding Panel (Windows Desktop)
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
                                'Acadova Quiz Portal',
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
                                'Interactive assessment platform for modern learning. Take quizzes, track performance, and excel academically.',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: Colors.white.withAlpha(225),
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  _buildBadge(Icons.quiz_outlined, 'Real-time Quizzes'),
                                  const SizedBox(width: 12),
                                  _buildBadge(Icons.analytics_outlined, 'Instant Score'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right Login Form Panel (Windows Desktop)
                      Expanded(
                        flex: 6,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: loginFormContent,
                            ),
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
}


