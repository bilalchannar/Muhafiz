import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/providers/auth_provider.dart';
import 'package:muhafiz/providers/mode_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/providers/settings_provider.dart';
import 'package:muhafiz/models/app_settings_model.dart';
import 'package:muhafiz/router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Clear local data?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will remove your local profile, trusted contacts, and safety preferences from this device.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear Data',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(trusteesProvider.notifier).clear();
    await ref.read(modeProvider.notifier).clear();
    await ref.read(userProvider.notifier).clear();
    await ref.read(settingsProvider.notifier).reset();
    await ref.read(authStateProvider.notifier).logout();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (_) => false);
    }
  }

  void _editEmergencyMessage(String currentMessage) {
    final controller = TextEditingController(text: currentMessage);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit SOS Message'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 160,
          decoration: const InputDecoration(
            hintText: 'Enter your emergency SOS message...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newMsg = controller.text.trim();
              if (newMsg.isNotEmpty) {
                await ref.read(settingsProvider.notifier).updateEmergencyMessage(newMsg);
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editCountdown(int currentSeconds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency Countdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 20, 30].map((s) {
            return RadioListTile<int>(
              title: Text('$s seconds'),
              value: s,
              groupValue: currentSeconds,
              activeColor: AppColors.primary,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateCountdown(val);
                }
                if (mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _editRepeatInterval(int currentMinutes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alert Repeat Interval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [2, 5, 10, 15, 30].map((m) {
            return RadioListTile<int>(
              title: Text('$m minutes'),
              value: m,
              groupValue: currentMinutes,
              activeColor: AppColors.primary,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(settingsProvider.notifier).updateRepeatInterval(val);
                }
                if (mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _editNotificationSound() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification Sound'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Default System', 'Loud Siren', 'Soft Chime', 'Alert Tone'].map((sound) {
            return ListTile(
              title: Text(sound),
              trailing: sound == 'Default System' ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected sound: $sound')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(fontSize: 14, height: 1.4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLocalData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting local data to safety_export.json... Done!')),
    );
  }

  Future<void> _backupSafetySettings(AppSettingsModel settings) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backing up settings to Firebase... Done!')),
    );
    await ref.read(settingsProvider.notifier).updateSettings(settings);
  }

  void _showPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This feature will be available after integration.')),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.black.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _settingTile({
    required String label,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap ?? _showPlaceholder,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.black.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.black,
                ),
              ),
            ),
            if (trailing != null) trailing else const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _settingTile(
      label: label,
      icon: icon,
      trailing: SizedBox(
        height: 24,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
          activeThumbColor: AppColors.primary,
        ),
      ),
      onTap: () => onChanged(!value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Settings', 'Customize your Muhafiz experience.'),
              const SizedBox(height: 24),
              
              _sectionTitle('Safety Preferences'),
              _card(children: [
                _settingTile(
                  label: 'Default emergency message',
                  icon: Icons.message_outlined,
                  onTap: () => _editEmergencyMessage(settings.defaultEmergencyMessage),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Emergency countdown',
                  icon: Icons.timer_outlined,
                  trailing: Text('${settings.emergencyCountdownSeconds}s', style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  onTap: () => _editCountdown(settings.emergencyCountdownSeconds),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Alert repeat interval',
                  icon: Icons.repeat_rounded,
                  trailing: Text('${settings.alertRepeatIntervalMinutes}m', style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  onTap: () => _editRepeatInterval(settings.alertRepeatIntervalMinutes),
                ),
                const Divider(height: 1, indent: 48),
                _switchTile(
                  label: 'Auto-share location',
                  icon: Icons.location_on_outlined,
                  value: settings.autoShareLocation,
                  onChanged: (v) => settingsNotifier.updateSettings(settings.copyWith(autoShareLocation: v)),
                ),
                const Divider(height: 1, indent: 48),
                _switchTile(
                  label: 'Protective mode reminders',
                  icon: Icons.notifications_paused_outlined,
                  value: settings.vulnerableRemindersEnabled,
                  onChanged: (v) => settingsNotifier.updateSettings(settings.copyWith(vulnerableRemindersEnabled: v)),
                ),
              ]),
              const SizedBox(height: 20),

              _sectionTitle('Notifications'),
              _card(children: [
                _switchTile(
                  label: 'Emergency alerts',
                  icon: Icons.notification_important_outlined,
                  value: settings.emergencyNotificationsEnabled,
                  onChanged: (v) => settingsNotifier.updateSettings(settings.copyWith(emergencyNotificationsEnabled: v)),
                ),
                const Divider(height: 1, indent: 48),
                _switchTile(
                  label: 'Protective reminders',
                  icon: Icons.shield_outlined,
                  value: settings.vulnerableRemindersEnabled,
                  onChanged: (v) => settingsNotifier.updateSettings(settings.copyWith(vulnerableRemindersEnabled: v)),
                ),
                const Divider(height: 1, indent: 48),
                _switchTile(
                  label: 'Trustee updates',
                  icon: Icons.people_outline,
                  value: settings.trusteeUpdatesEnabled,
                  onChanged: (v) => settingsNotifier.updateSettings(settings.copyWith(trusteeUpdatesEnabled: v)),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Notification sound',
                  icon: Icons.volume_up_outlined,
                  onTap: _editNotificationSound,
                ),
              ]),
              const SizedBox(height: 20),

              _sectionTitle('Privacy & Security'),
              _card(children: [
                _switchTile(
                  label: 'App lock',
                  icon: Icons.lock_outline,
                  value: settings.appLockEnabled,
                  onChanged: (v) => settingsNotifier.updateSettings(settings.copyWith(appLockEnabled: v)),
                ),
                const Divider(height: 1, indent: 48),
                _switchTile(
                  label: 'Hide sensitive content',
                  icon: Icons.visibility_off_outlined,
                  value: settings.hideSensitiveAlertContent,
                  onChanged: (v) => settingsNotifier.updateSettings(settings.copyWith(hideSensitiveAlertContent: v)),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Location settings',
                  icon: Icons.map_outlined,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.locationPermission),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Battery Optimization',
                  icon: Icons.battery_charging_full_outlined,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.batteryOptimization),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Clear local data',
                  icon: Icons.delete_outline,
                  textColor: AppColors.primary,
                  iconColor: AppColors.primary,
                  onTap: _clearAllData,
                ),
              ]),
              const SizedBox(height: 20),

              _sectionTitle('Data & Storage'),
              _card(children: [
                _settingTile(
                  label: 'Export local data',
                  icon: Icons.download_outlined,
                  onTap: _exportLocalData,
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Backup safety settings',
                  icon: Icons.backup_outlined,
                  onTap: () => _backupSafetySettings(settings),
                ),
              ]),
              const SizedBox(height: 20),

              _sectionTitle('Help & Support'),
              _card(children: [
                _settingTile(
                  label: 'Help Center',
                  icon: Icons.help_outline,
                  onTap: () => _showInfoDialog('Help Center', 'Welcome to the Help Center. Here you can find articles on how to set up trusted contacts, configure SOS countdowns, and customize protective travel alerts.'),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Contact Support',
                  icon: Icons.support_agent_outlined,
                  onTap: () => _showInfoDialog('Contact Support', 'If you have any feedback or face technical issues, please contact us at support@muhafizapp.com.'),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Report a Problem',
                  icon: Icons.report_problem_outlined,
                  onTap: () => _showInfoDialog('Report a Problem', 'Please describe the issue you encountered and send it to bugs@muhafizapp.com along with any error logs.'),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Safety Guidelines',
                  icon: Icons.gavel_outlined,
                  onTap: () => _showInfoDialog('Safety Guidelines', '1. Keep your GPS enabled at all times.\n2. Ensure your phone number format includes country codes.\n3. Keep at least two trusted contacts registered for automated SOS WhatsApp messages.'),
                ),
              ]),
              const SizedBox(height: 20),

              _sectionTitle('About Muhafiz'),
              _card(children: [
                _settingTile(
                  label: 'App Version',
                  icon: Icons.info_outline,
                  trailing: const Text('1.0.0', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                  onTap: () => _showInfoDialog('App Version', 'Muhafiz Safe Travels\nVersion: 1.0.0\nBuilt with Flutter & Node.js.'),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => _showInfoDialog('Privacy Policy', 'Muhafiz is committed to protecting your privacy. Your personal information, locations, and contacts are stored securely and only shared with selected contacts during active SOS safety workflows.'),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Terms & Conditions',
                  icon: Icons.description_outlined,
                  onTap: () => _showInfoDialog('Terms & Conditions', 'By using Muhafiz, you agree that safety mode utilizes your cellular network and internet capabilities to deliver notifications. Standard carrier rates may apply for external SMS/calls.'),
                ),
                const Divider(height: 1, indent: 48),
                _settingTile(
                  label: 'Open-source licenses',
                  icon: Icons.code_outlined,
                  onTap: () => _showInfoDialog('Licenses', 'Muhafiz includes libraries and open source software under the MIT, BSD, and Apache 2.0 licenses.'),
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
