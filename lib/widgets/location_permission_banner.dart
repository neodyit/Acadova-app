import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/app_theme.dart';
import '../widgets/custom_toast.dart';

class LocationPermissionBannerDialog extends StatefulWidget {
  final String quizTitle;
  final VoidCallback onPermissionGranted;

  const LocationPermissionBannerDialog({
    super.key,
    required this.quizTitle,
    required this.onPermissionGranted,
  });

  /// Entry point to ensure location permission before attempting a quiz.
  /// If location permission is ALREADY granted, returns location details immediately without showing dialog.
  /// If NOT granted, presents the LocationPermissionBannerDialog to request permission.
  static Future<Map<String, String>?> requestAndFetchLocation(BuildContext context, String quizTitle) async {
    if (!context.mounted) return null;

    // 1. Check if location services and permissions are already granted
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (serviceEnabled && (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
        // Permission is already granted! Fetch location and proceed directly.
        return await _fetchLocationDetails();
      }
    } catch (_) {
      // If check fails, fall through to show banner dialog
    }

    if (!context.mounted) return null;

    // 2. Location permission not yet granted -> Show location permission banner
    Map<String, String>? result;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LocationPermissionBannerDialog(
        quizTitle: quizTitle,
        onPermissionGranted: () async {
          final loc = await _fetchLocationDetails();
          result = loc;
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
    return result;
  }

  static Future<Map<String, String>> _fetchLocationDetails() async {
    String lat = '';
    String lng = '';
    String locationName = 'Location Granted';

    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos != null) {
        lat = pos.latitude.toString();
        lng = pos.longitude.toString();
        locationName = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';

        try {
          final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}');
          final res = await http.get(url, headers: {'User-Agent': 'AcadovaQuizApp/1.0'}).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['display_name'] != null) {
              locationName = data['display_name'];
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return {
      'latitude': lat,
      'longitude': lng,
      'location': locationName,
    };
  }

  @override
  State<LocationPermissionBannerDialog> createState() => _LocationPermissionBannerDialogState();
}

class _LocationPermissionBannerDialogState extends State<LocationPermissionBannerDialog> {
  bool _isChecking = false;

  Future<void> _handlePermissionRequest() async {
    setState(() => _isChecking = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          CustomToast.show(
            context,
            title: 'GPS Disabled',
            message: 'Please enable Location Services (GPS) on your device to proceed.',
            type: ToastType.warning,
          );
        }
        await Geolocator.openLocationSettings();
        setState(() => _isChecking = false);
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
            message: 'Location permission is permanently denied. Please enable it in App Settings.',
            type: ToastType.error,
          );
          await Geolocator.openAppSettings();
        }
        setState(() => _isChecking = false);
        return;
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        widget.onPermissionGranted();
      } else {
        if (mounted) {
          CustomToast.show(
            context,
            title: 'Location Required',
            message: 'Location permission is required to start the quiz.',
            type: ToastType.warning,
          );
        }
        setState(() => _isChecking = false);
      }
    } catch (e) {
      // Fallback: If exception occurs, proceed so user is not blocked
      if (mounted) {
        widget.onPermissionGranted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header with Gradient Accent Ring
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.15),
                      AppTheme.primaryDark.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.gavel_rounded,
                    size: 34,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Dialog Title
              const Text(
                'Proctoring & Location Verification',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mainText,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description Text
              Text(
                'To ensure academic integrity for "${widget.quizTitle}", location verification is required while completing this assessment.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Security & Integrity Info Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your location is used solely to verify session authenticity during test submission.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mainText,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _handlePermissionRequest,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.verified_user_rounded, size: 18),
                  label: Text(
                    _isChecking ? 'Verifying Permission...' : 'Grant & Start Quiz',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Cancel Assessment',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
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
