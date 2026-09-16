import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/custom_toast.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const SettingsScreen({
    super.key,
    this.userData,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const MethodChannel _securityChannel = MethodChannel('com.neodyit.acadova/security');

  // Preference states
  bool _pushNotifications = true;
  bool _quizReminders = true;
  bool _campaignAlerts = true;
  bool _dndMode = false;
  bool _darkMode = false;
  bool _soundEffects = true;
  bool _vibration = true;
  bool _biometrics = false;
  bool _isLoading = true;

  double _cacheSizeMb = 4.8;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool dndActive = false;

      if (!kIsWeb && Platform.isAndroid) {
        try {
          final bool active = await _securityChannel.invokeMethod('isDndActive');
          dndActive = active;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _pushNotifications = prefs.getBool('pref_push_notifications') ?? true;
          _quizReminders = prefs.getBool('pref_quiz_reminders') ?? true;
          _campaignAlerts = prefs.getBool('pref_campaign_alerts') ?? true;
          _dndMode = dndActive;
          _darkMode = prefs.getBool('pref_dark_mode') ?? false;
          _soundEffects = prefs.getBool('pref_sound_effects') ?? true;
          _vibration = prefs.getBool('pref_vibration') ?? true;
          _biometrics = prefs.getBool('pref_biometrics') ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear non-auth keys
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key != 'auth_token' && key != 'user_data') {
          await prefs.remove(key);
        }
      }
      if (mounted) {
        setState(() {
          _cacheSizeMb = 0.0;
        });
        CustomToast.show(
          context,
          message: 'App cache cleared successfully!',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Failed to clear cache.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D3436), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Settings & Preferences',
            style: TextStyle(
              color: Color(0xFF2D3436),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D3436), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings & Preferences',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifications Section
            _buildSectionTitle('Notifications'),
            _buildCardContainer([
              _buildSwitchTile(
                icon: Icons.notifications_active_outlined,
                iconColor: const Color(0xFF6C5CE7),
                title: 'Push Notifications',
                subtitle: 'Receive alerts for quizzes and events',
                value: _pushNotifications,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                  _savePreference('pref_push_notifications', val);
                  CustomToast.show(
                    context,
                    message: val ? 'Push notifications enabled' : 'Push notifications disabled',
                    type: ToastType.info,
                  );
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.alarm_rounded,
                iconColor: const Color(0xFF00B894),
                title: 'Quiz Reminders',
                subtitle: 'Get notified 30 mins before active quizzes end',
                value: _quizReminders,
                onChanged: (val) {
                  setState(() => _quizReminders = val);
                  _savePreference('pref_quiz_reminders', val);
                  CustomToast.show(
                    context,
                    message: val ? 'Quiz reminders enabled' : 'Quiz reminders disabled',
                    type: ToastType.info,
                  );
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFFE17055),
                title: 'Campaign & Notice Alerts',
                subtitle: 'Announcements and featured league updates',
                value: _campaignAlerts,
                onChanged: (val) {
                  setState(() => _campaignAlerts = val);
                  _savePreference('pref_campaign_alerts', val);
                  CustomToast.show(
                    context,
                    message: val ? 'Campaign alerts enabled' : 'Campaign alerts disabled',
                    type: ToastType.info,
                  );
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.do_not_disturb_on_outlined,
                iconColor: const Color(0xFFD63031),
                title: 'Do Not Disturb (DND) Mode',
                subtitle: 'Silence incoming calls & alerts on device',
                value: _dndMode,
                onChanged: (val) async {
                  if (!kIsWeb && Platform.isAndroid) {
                    final bool isGranted = await _securityChannel.invokeMethod('isDndPermissionGranted');
                    if (!isGranted) {
                      await _securityChannel.invokeMethod('requestDndPermission');
                      if (mounted) {
                        CustomToast.show(
                          context,
                          title: 'Permission Required',
                          message: 'Please grant Do Not Disturb policy access in Android Settings.',
                          type: ToastType.warning,
                        );
                      }
                      return;
                    }

                    final bool success = await _securityChannel.invokeMethod(val ? 'enableDndMode' : 'disableDndMode');
                    if (success) {
                      setState(() => _dndMode = val);
                      if (mounted) {
                        CustomToast.show(
                          context,
                          message: val ? 'Do Not Disturb Mode Enabled' : 'Do Not Disturb Mode Disabled',
                          type: ToastType.success,
                        );
                      }
                    } else {
                      if (mounted) {
                        CustomToast.show(
                          context,
                          message: 'Failed to change DND mode status.',
                          type: ToastType.error,
                        );
                      }
                    }
                  } else {
                    setState(() => _dndMode = val);
                  }
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Appearance & Experience Section
            _buildSectionTitle('Appearance & Audio'),
            _buildCardContainer([
              _buildSwitchTile(
                icon: Icons.style_outlined,
                iconColor: const Color(0xFFE84393),
                title: 'Card Mode',
                subtitle: 'Interactive flashcard layout for studying',
                value: false,
                isComingSoon: true,
                onChanged: (val) {},
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                iconColor: const Color(0xFF0984E3),
                title: 'Dark Mode',
                subtitle: 'Sleek dark theme for night studying',
                value: false,
                isComingSoon: true,
                onChanged: (val) {},
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.volume_up_outlined,
                iconColor: const Color(0xFFFD79A8),
                title: 'Sound Effects',
                subtitle: 'Play sounds during quiz completion',
                value: _soundEffects,
                onChanged: (val) {
                  setState(() => _soundEffects = val);
                  _savePreference('pref_sound_effects', val);
                  CustomToast.show(
                    context,
                    message: val ? 'Sound effects enabled' : 'Sound effects muted',
                    type: ToastType.info,
                  );
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.vibration_rounded,
                iconColor: const Color(0xFF6C5CE7),
                title: 'Haptic Feedback',
                subtitle: 'Vibrate on selecting answers',
                value: _vibration,
                onChanged: (val) {
                  setState(() => _vibration = val);
                  _savePreference('pref_vibration', val);
                  CustomToast.show(
                    context,
                    message: val ? 'Haptic feedback enabled' : 'Haptic feedback disabled',
                    type: ToastType.info,
                  );
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Security & Privacy
            _buildSectionTitle('Security & Privacy'),
            _buildCardContainer([
              _buildSwitchTile(
                icon: Icons.fingerprint_rounded,
                iconColor: const Color(0xFF00B894),
                title: 'Biometric Lock',
                subtitle: 'Require FaceID / Fingerprint to open app',
                value: _biometrics,
                isComingSoon: true,
                onChanged: (val) {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF0984E3)),
                title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
                onTap: () async {
                  final Uri url = Uri.parse('https://acadova.neodyit.com/privacy-policy');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_outlined, color: Color(0xFFE17055)),
                title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
                onTap: () async {
                  final Uri url = Uri.parse('https://acadova.neodyit.com/terms-of-service');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF6C5CE7)),
                title: const Text('Help Center', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
                onTap: () async {
                  final Uri url = Uri.parse('https://acadova.neodyit.com/help-center');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Storage & System
            _buildSectionTitle('Storage & Maintenance'),
            _buildCardContainer([
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined, color: Color(0xFFE17055)),
                title: const Text('Clear App Cache', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Temporary data: ${_cacheSizeMb.toStringAsFixed(1)} MB'),
                trailing: ElevatedButton(
                  onPressed: _cacheSizeMb > 0 ? _clearCache : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE17055),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Clear', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // App Info Section
            _buildSectionTitle('About Acadova'),
            _buildCardContainer([
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF6C5CE7)),
                title: const Text('App Version', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('v${AppConfig.appVersion}+${AppConfig.buildNumber}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ApiService.isUpdateAvailable()
                        ? const Color(0xFFD63031).withValues(alpha: 0.15)
                        : const Color(0xFF00B894).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ApiService.isUpdateAvailable() ? 'Update' : 'Latest',
                    style: TextStyle(
                      color: ApiService.isUpdateAvailable()
                          ? const Color(0xFFD63031)
                          : const Color(0xFF00B894),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () async {
                  CustomToast.show(context, message: 'Checking for updates...', type: ToastType.info);
                  await ApiService.fetchAppSettings();
                  if (!context.mounted) return;

                  if (ApiService.isUpdateAvailable()) {
                    AppUpdateDialog.show(context, force: ApiService.isForceUpdateRequired());
                  } else {
                    CustomToast.show(
                      context,
                      message: 'You are on the latest version of Acadova (v${AppConfig.appVersion})!',
                      type: ToastType.success,
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                title: const Text('WhatsApp Support', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('+91 6205045881'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Chat',
                    style: TextStyle(color: Color(0xFF25D366), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () async {
                  const url = 'https://wa.me/916205045881?text=Hello%20Acadova%20Support';
                  final uri = Uri.parse(url);
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                      return;
                    }
                  } catch (_) {}
                  if (context.mounted) {
                    CustomToast.show(
                      context,
                      message: 'WhatsApp Support: +916205045881',
                      type: ToastType.info,
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF0984E3)),
                title: const Text('Help Desk & Support', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('support@neodyit.in'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () {
                  CustomToast.show(
                    context,
                    message: 'Contacting Support at support@neodyit.in',
                    type: ToastType.info,
                  );
                },
              ),
            ]),

            const SizedBox(height: 40),
            Center(
              child: Text(
                'Acadova Quiz App • Designed for Academic Excellence',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isComingSoon = false,
  }) {
    return SwitchListTile(
      value: isComingSoon ? false : value,
      onChanged: isComingSoon
          ? (val) {
              CustomToast.show(
                context,
                message: '$title feature is coming soon in an upcoming update!',
                type: ToastType.info,
              );
            }
          : onChanged,
      activeThumbColor: const Color(0xFF6C5CE7),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isComingSoon) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
              ),
              child: const Text(
                'SOON',
                style: TextStyle(
                  color: Color(0xFF6C5CE7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF6C5CE7))),
          ),
        ],
      ),
    );
  }
}
