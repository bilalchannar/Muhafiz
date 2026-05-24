import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/safety_mode_model.dart';
import 'package:muhafiz/providers/location_provider.dart';
import 'package:muhafiz/providers/auth_provider.dart';
import 'package:muhafiz/providers/mode_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/providers/app_service_providers.dart';
import 'package:muhafiz/router.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  (String, Color) _modeLabelAndColor(SafetyMode mode) {
    switch (mode) {
      case SafetyMode.vulnerable:
        return ('Vulnerable', AppColors.vulnerable);
      case SafetyMode.emergency:
        return ('Emergency', AppColors.primary);
      case SafetyMode.normal:
        return ('Normal', AppColors.safe);
    }
  }

  String _modeDescription(SafetyMode mode) {
    switch (mode) {
      case SafetyMode.vulnerable:
        return 'Automatic check-ins are active.';
      case SafetyMode.emergency:
        return 'Emergency mode is active.';
      case SafetyMode.normal:
        return 'No active safety mode.';
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authStateProvider.notifier).logout();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.welcome,
          (route) => false,
        );
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.black.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _tipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppColors.safe, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.black.withValues(alpha: 0.65),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final modeState = ref.watch(modeProvider);
    final trustees = ref.watch(trusteesProvider);
    final location = ref.watch(locationProvider);
    final modeData = _modeLabelAndColor(modeState.currentMode);
    final name = user?.name?.trim().isNotEmpty == true ? user!.name! : 'there';
    final contactsCount = trustees.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Muhafiz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $name',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your safety status is being monitored.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Safety Status'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: modeData.$2,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current mode: ${modeData.$1}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: modeData.$2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _modeDescription(modeState.currentMode),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoRow('Trusted contacts', '$contactsCount'),
                    const SizedBox(height: 6),
                    _infoRow('Location status', location.statusLabel),
                    const SizedBox(height: 6),
                    _infoRow(
                      'Last check-in',
                      modeState.lastCheckInAt != null
                          ? _formatTime(modeState.lastCheckInAt!)
                          : 'Not available',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (modeState.currentMode != SafetyMode.normal) ...[
                PrimaryButton(
                  text: 'I am safe now',
                  onPressed: () {
                    ref.read(alertDeliveryServiceProvider).stopRealtimeService();
                    ref.read(modeProvider.notifier).reset();
                  },
                ),
                const SizedBox(height: 18),
              ],
              _sectionTitle('Quick Actions'),
              const SizedBox(height: 10),
              _actionCard(
                title: 'Emergency SOS',
                subtitle: 'Send alert to trusted contacts',
                icon: Icons.warning_rounded,
                accent: AppColors.primary,
                onTap: () => Navigator.pushNamed(context, AppRoutes.emergency),
              ),
              const SizedBox(height: 12),
              _actionCard(
                title: 'Going somewhere alone?',
                subtitle: 'Start protective mode for automatic check-ins.',
                icon: Icons.shield_outlined,
                accent: const Color(0xFFF2C94C),
                onTap: () => Navigator.pushNamed(context, AppRoutes.vulnerable),
              ),
              const SizedBox(height: 18),
              _sectionTitle('Trusted Contacts'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$contactsCount trusted contact${contactsCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (contactsCount == 0)
                      Text(
                        'Add at least one trusted contact to use emergency alerts.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.black.withValues(alpha: 0.6),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: trustees
                            .take(3)
                            .map(
                              (trustee) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  trustee.name,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.contacts),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Manage contacts'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionTitle('Device Permissions'),
              const SizedBox(height: 10),
              _actionCard(
                title: 'Location Permission',
                subtitle: 'Enable location access for safety workflows.',
                icon: Icons.my_location_rounded,
                accent: const Color(0xFF1976D2),
                onTap: () => Navigator.pushNamed(context, AppRoutes.locationPermission),
              ),
              const SizedBox(height: 18),
              _sectionTitle('Recent Activity'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'No recent alerts',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Profile updated',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Trusted contact added',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionTitle('Safety Tips'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  children: [
                    _tipItem('Keep your location enabled during travel.'),
                    const SizedBox(height: 8),
                    _tipItem('Add at least two trusted contacts.'),
                    const SizedBox(height: 8),
                    _tipItem('Use protective mode when travelling alone.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
