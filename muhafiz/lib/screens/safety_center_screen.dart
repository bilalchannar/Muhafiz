import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/safety_mode_model.dart';
import 'package:muhafiz/providers/location_provider.dart';
import 'package:muhafiz/providers/mode_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/router.dart';

class SafetyCenterScreen extends ConsumerWidget {
  const SafetyCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final modeState = ref.watch(modeProvider);
    final trustees = ref.watch(trusteesProvider);
    final location = ref.watch(locationProvider);
    final name = user?.name?.trim().isNotEmpty == true ? user!.name! : 'User';
    final contactsCount = trustees.length;

    final modeLabel = switch (modeState.currentMode) {
      SafetyMode.vulnerable => 'Protective',
      SafetyMode.emergency => 'Emergency',
      SafetyMode.normal => 'Normal',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Safety Center')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Safety Center',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your emergency tools, safety modes, and trusted protection features.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safety status for $name',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow('Current mode', modeLabel),
                    const SizedBox(height: 6),
                    _infoRow('Trusted contacts', '$contactsCount'),
                    const SizedBox(height: 6),
                    _infoRow('Location status', location.statusLabel),
                    const SizedBox(height: 6),
                    _infoRow('Notifications', 'Ready'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Safety actions'),
              const SizedBox(height: 10),
              _actionCard(
                context,
                title: 'Emergency Mode',
                subtitle: 'Activate SOS and alert trusted contacts.',
                icon: Icons.warning_rounded,
                accent: AppColors.primary,
                route: AppRoutes.emergency,
              ),
              const SizedBox(height: 12),
              _actionCard(
                context,
                title: 'Protective Mode',
                subtitle: 'Schedule safety check-ins while travelling alone.',
                icon: Icons.shield_rounded,
                accent: AppColors.vulnerable,
                route: AppRoutes.vulnerable,
              ),
              const SizedBox(height: 12),

              _actionCard(
                context,
                title: 'Location Permission',
                subtitle: 'Enable location access for safety workflows.',
                icon: Icons.my_location_rounded,
                accent: const Color(0xFF1976D2),
                route: AppRoutes.locationPermission,
              ),
              const SizedBox(height: 16),
              _sectionTitle('Safety tips'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  children: const [
                    _TipItem('Add at least two trusted contacts.'),
                    SizedBox(height: 8),
                    _TipItem('Keep your phone location enabled while travelling.'),
                    SizedBox(height: 8),
                    _TipItem('Use protective mode when going somewhere alone.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
      ),
      child: child,
    );
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

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required String route,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (route.isEmpty) {
          _showPlaceholder(context);
          return;
        }
        try {
          Navigator.pushNamed(context, route);
        } catch (_) {
          _showPlaceholder(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
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

  void _showPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This feature will be available later.')),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;

  const _TipItem(this.text);

  @override
  Widget build(BuildContext context) {
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
}
