import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import 'custom_toast.dart';

class AppUpdateDialog extends StatelessWidget {
  final bool isForceUpdate;
  final String latestVersion;
  final String updateUrl;
  final String releaseNotes;

  const AppUpdateDialog({
    super.key,
    required this.isForceUpdate,
    required this.latestVersion,
    required this.updateUrl,
    required this.releaseNotes,
  });

  static Future<void> show(
    BuildContext context, {
    bool force = false,
  }) async {
    final latest = ApiService.latestAppVersion;
    final url = ApiService.updateUrl;
    final notes = ApiService.releaseNotes;

    await showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: AppUpdateDialog(
          isForceUpdate: force,
          latestVersion: latest,
          updateUrl: url,
          releaseNotes: notes,
        ),
      ),
    );
  }

  Future<void> _launchUpdateUrl(BuildContext context) async {
    final uri = Uri.tryParse(updateUrl);
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
    if (context.mounted) {
      CustomToast.show(
        context,
        message: 'Opening download link: $updateUrl',
        type: ToastType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF6C5CE7);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFFA29BFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.system_update_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              isForceUpdate ? 'Mandatory Update Required' : 'New Update Available!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3436),
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 8),

            // Version Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'v${AppConfig.appVersion}  ➔  v$latestVersion',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Message / Release Notes
            Text(
              isForceUpdate
                  ? 'A critical update is required to continue using Acadova safely. Please update to the latest version.'
                  : 'A new version of Acadova is available with performance improvements and new features.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF636E72),
                height: 1.45,
              ),
            ),

            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDFE6E9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What\'s New:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      releaseNotes,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF636E72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                if (!isForceUpdate) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Color(0xFFDFE6E9)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Later',
                        style: TextStyle(
                          color: Color(0xFF636E72),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: primaryColor,
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _launchUpdateUrl(context),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
