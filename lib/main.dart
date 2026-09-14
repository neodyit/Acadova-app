import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Custom Error Boundary to prevent silent white screen crashes on device unlock/resume
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.refresh_rounded, size: 48, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Application Resumed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.mainText),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Session connection refreshed. Tap below to reload your workspace.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      final nav = navigatorKey.currentState;
                      if (nav != null) {
                        nav.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const SplashScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reload Application', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  // Register session expired / deleted user handler 
  ApiService.onUnauthorized = () {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  };

  runApp(const AcadovaApp());
}

class AcadovaApp extends StatelessWidget {
  const AcadovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Acadova',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name != null) {
          final uri = Uri.parse(settings.name!);
          if (uri.path == '/reset-password' || uri.host == 'reset-password') {
            final token = uri.queryParameters['token'] ?? '';
            final email = uri.queryParameters['email'] ?? '';
            if (token.isNotEmpty && email.isNotEmpty) {
              return MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(email: email, token: token),
              );
            }
          }
        }
        return null;
      },
    );
  }
}
