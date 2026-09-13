import 'package:flutter/material.dart';
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
  // Preference states
  bool _pushNotifications = true;
  bool _quizReminders = true;
  bool _campaignAlerts = true;
  bool _darkMode = false;
  bool _soundEffects = true;
  bool _vibration = true;
  bool _biometrics = false;

  double _cacheSizeMb = 14.2;

  void _clearCache() {
    setState(() {
      _cacheSizeMb = 0.0;
    });
    CustomToast.show(
      context,
      message: 'App cache cleared successfully!',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                onChanged: (val) => setState(() => _pushNotifications = val),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.alarm_rounded,
                iconColor: const Color(0xFF00B894),
                title: 'Quiz Reminders',
                subtitle: 'Get notified 30 mins before active quizzes end',
                value: _quizReminders,
                onChanged: (val) => setState(() => _quizReminders = val),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFFE17055),
                title: 'Campaign & Notice Alerts',
                subtitle: 'Announcements and featured league updates',
                value: _campaignAlerts,
                onChanged: (val) => setState(() => _campaignAlerts = val),
              ),
            ]),

            const SizedBox(height: 24),

            // Appearance & Experience Section
            _buildSectionTitle('Appearance & Audio'),
            _buildCardContainer([
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                iconColor: const Color(0xFF0984E3),
                title: 'Dark Mode',
                subtitle: 'Sleek dark theme for night studying',
                value: _darkMode,
                onChanged: (val) {
                  setState(() => _darkMode = val);
                  CustomToast.show(
                    context,
                    message: val ? 'Dark mode enabled' : 'Light mode enabled',
                    type: ToastType.info,
                  );
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.volume_up_outlined,
                iconColor: const Color(0xFFFD79A8),
                title: 'Sound Effects',
                subtitle: 'Play sounds during quiz completion',
                value: _soundEffects,
                onChanged: (val) => setState(() => _soundEffects = val),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.vibration_rounded,
                iconColor: const Color(0xFF6C5CE7),
                title: 'Haptic Feedback',
                subtitle: 'Vibrate on selecting answers',
                value: _vibration,
                onChanged: (val) => setState(() => _vibration = val),
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
                onChanged: (val) => setState(() => _biometrics = val),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF0984E3)),
                title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
                onTap: () => _showDialog('Privacy Policy', 'Acadova values your data privacy. All student quiz attempts and academic scores are strictly encrypted.'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_outlined, color: Color(0xFFE17055)),
                title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
                onTap: () => _showDialog('Terms of Service', 'By using Acadova, students agree to adhere to academic integrity and anti-cheating guidelines.'),
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
                subtitle: const Text('v1.0.0 (Build 2026.1)'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Latest',
                    style: TextStyle(color: Color(0xFF00B894), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
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
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF6C5CE7),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
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
