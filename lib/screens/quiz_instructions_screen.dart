import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_theme.dart';
import '../widgets/custom_toast.dart';
import 'quiz_attempt_screen.dart';

class QuizPreInstructionsScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final List<Map<String, dynamic>> questions;

  const QuizPreInstructionsScreen({
    super.key,
    required this.quiz,
    required this.questions,
  });

  @override
  State<QuizPreInstructionsScreen> createState() => _QuizPreInstructionsScreenState();
}

class _QuizPreInstructionsScreenState extends State<QuizPreInstructionsScreen> {
  static const MethodChannel _securityChannel = MethodChannel('com.neodyit.acadova/security');

  bool _isLocationGranted = false;
  bool _isDndGranted = false;
  bool _isLoadingPermissionCheck = true;
  bool _isRequestingLocation = false;

  Map<String, String>? _locationDetails;

  @override
  void initState() {
    super.initState();
    _checkPermissionsStatus();
  }

  Future<void> _checkPermissionsStatus() async {
    setState(() {
      _isLoadingPermissionCheck = true;
    });

    // 1. Check Location Status
    bool locGranted = false;
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      locGranted = true;
      _locationDetails = await _fetchDesktopIpLocationDetails();
    } else {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        LocationPermission permission = await Geolocator.checkPermission();
        if (serviceEnabled && (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
          locGranted = true;
          _locationDetails = await _fetchLocationDetails();
        }
      } catch (_) {}
    }

    // 2. Check DND Status
    bool dndGranted = true;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final bool res = await _securityChannel.invokeMethod('isDndPermissionGranted');
        dndGranted = res;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isLocationGranted = locGranted;
        _isDndGranted = dndGranted;
        _isLoadingPermissionCheck = false;
      });
    }
  }

  static Future<Map<String, String>> _fetchDesktopIpLocationDetails() async {
    try {
      final uri = Uri.parse('http://ip-api.com/json/');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          final city = data['city'] ?? '';
          final region = data['regionName'] ?? '';
          final country = data['country'] ?? '';
          final lat = (data['lat'] ?? 0.0).toString();
          final lon = (data['lon'] ?? 0.0).toString();

          final locationParts = [city, region, country].where((e) => e.toString().isNotEmpty).join(', ');

          return {
            'latitude': lat,
            'longitude': lon,
            'location': locationParts.isNotEmpty ? locationParts : 'Desktop Verified',
          };
        }
      }
    } catch (_) {}

    return {
      'latitude': '0.0000',
      'longitude': '0.0000',
      'location': 'Desktop Verified',
    };
  }

  static Future<Map<String, String>> _fetchLocationDetails() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      String formattedLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json',
        );
        final res = await http.get(uri, headers: {'User-Agent': 'AcadovaQuizApp/1.0'}).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['display_name'] != null) {
            formattedLocation = data['display_name'].toString();
          }
        }
      } catch (_) {}

      return {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'location': formattedLocation,
      };
    } catch (_) {
      return {
        'latitude': '0.0000',
        'longitude': '0.0000',
        'location': 'Location Verified',
      };
    }
  }

  Future<void> _requestLocationPermission() async {
    if (_isRequestingLocation) return;
    setState(() => _isRequestingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          CustomToast.show(
            context,
            title: 'Location Services Disabled',
            message: 'Please turn on GPS/Location services on your device.',
            type: ToastType.warning,
          );
        }
        await Geolocator.openLocationSettings();
        setState(() => _isRequestingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          CustomToast.show(
            context,
            title: 'Permission Denied',
            message: 'Location permission is permanently denied. Please enable it in Settings.',
            type: ToastType.error,
          );
        }
        await Geolocator.openAppSettings();
      } else if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final loc = await _fetchLocationDetails();
        if (mounted) {
          setState(() {
            _locationDetails = loc;
            _isLocationGranted = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, title: 'Error', message: 'Failed to access location: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isRequestingLocation = false);
    }
  }

  Future<void> _requestDndPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _securityChannel.invokeMethod('requestDndPermission');
        // Re-check after user returns from Android Settings
        await Future.delayed(const Duration(milliseconds: 1000));
        await _checkPermissionsStatus();
      } catch (_) {}
    }
  }

  void _startQuiz() {
    if (!_isLocationGranted) {
      CustomToast.show(
        context,
        title: 'Location Required',
        message: 'Please allow Location access before starting the proctored test.',
        type: ToastType.warning,
      );
      return;
    }

    if (!_isDndGranted) {
      CustomToast.show(
        context,
        title: 'DND Access Required',
        message: 'Please allow Do Not Disturb access so incoming calls do not disturb your test.',
        type: ToastType.warning,
      );
      return;
    }

    final quizTitle = widget.quiz['title'] ?? 'Quiz Attempt';
    final subject = widget.quiz['subject'];
    final durationMinutes = widget.quiz['durationMinutes'] ?? widget.quiz['duration_minutes'] ?? 15;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizAttemptScreen(
          quizId: widget.quiz['id'],
          quizTitle: quizTitle,
          subject: subject,
          durationMinutes: durationMinutes,
          questions: widget.questions,
          location: _locationDetails?['location'],
          latitude: _locationDetails?['latitude'],
          longitude: _locationDetails?['longitude'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.quiz['title'] ?? 'Quiz';
    final subject = widget.quiz['subject'] ?? 'General';
    final duration = widget.quiz['durationMinutes'] ?? widget.quiz['duration_minutes'] ?? 15;
    final totalQ = widget.questions.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Test Instructions & Environment Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.mainText,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quiz Header Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              subject.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSummaryBadge(Icons.timer_rounded, '$duration Mins'),
                              _buildSummaryBadge(Icons.quiz_rounded, '$totalQ Questions'),
                              _buildSummaryBadge(Icons.verified_user_rounded, 'Proctored'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SECTION 1: Required Permissions & System Consent
                    const Text(
                      '1. Environment & Security Checks',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.mainText),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To maintain test integrity, your device environment requires the following consents:',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 14),

                    if (_isLoadingPermissionCheck)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      // Location Permission Card
                      _buildPermissionCard(
                        title: 'Location Verification Consent',
                        description: 'Verifies geographical test attendance to prevent remote impersonation.',
                        icon: Icons.location_on_rounded,
                        isGranted: _isLocationGranted,
                        onTap: _requestLocationPermission,
                        isLoading: _isRequestingLocation,
                      ),
                      const SizedBox(height: 12),

                      // DND Permission Card
                      if (!kIsWeb && Platform.isAndroid)
                        _buildPermissionCard(
                          title: 'Do Not Disturb (DND) Consent',
                          description: 'Silence incoming call ringtones and popups during the exam session.',
                          icon: Icons.do_not_disturb_on_rounded,
                          isGranted: _isDndGranted,
                          onTap: _requestDndPermission,
                        ),
                    ],

                    const SizedBox(height: 28),

                    // SECTION 2: Anti-Cheat & Examination Guidelines
                    const Text(
                      '2. Examination Rules & Guidelines',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.mainText),
                    ),
                    const SizedBox(height: 12),

                    _buildInstructionRow(
                      icon: Icons.screen_lock_portrait_rounded,
                      title: 'App Lock & Full-Screen Mode',
                      subtitle: 'The app will be pinned during the test. Status bar & navigation gestures will be locked.',
                    ),
                    _buildInstructionRow(
                      icon: Icons.app_blocking_rounded,
                      title: 'Zero-Tolerance App Switching',
                      subtitle: 'Switching apps, opening split screen, or exiting is monitored. Max 3 violations allowed.',
                    ),
                    _buildInstructionRow(
                      icon: Icons.wifi_off_rounded,
                      title: 'Offline Submission Safeguard',
                      subtitle: 'If your internet drops at submission, your responses are securely saved locally & auto-synced.',
                    ),
                    _buildInstructionRow(
                      icon: Icons.lightbulb_rounded,
                      title: 'Automatic Screen Awake',
                      subtitle: 'Your device display will remain active throughout the quiz. Do not press the power button.',
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Start Quiz Action Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isLocationGranted && _isDndGranted) ? _startQuiz : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text(
                    "I'm Ready, Start Quiz",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final statusColor = isGranted ? const Color(0xFF10B981) : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? const Color(0xFFA7F3D0) : AppTheme.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted ? const Color(0xFFD1FAE5) : AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.mainText),
                      ),
                    ),
                    if (isGranted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Allowed', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                if (!isGranted) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Allow Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.mainText)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
