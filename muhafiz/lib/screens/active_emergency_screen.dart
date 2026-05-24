import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/providers/app_service_providers.dart';
import 'package:muhafiz/providers/mode_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/router.dart';
import 'package:muhafiz/widgets/outline_button.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class ActiveEmergencyScreen extends ConsumerStatefulWidget {
  const ActiveEmergencyScreen({super.key});

  @override
  ConsumerState<ActiveEmergencyScreen> createState() =>
      _ActiveEmergencyScreenState();
}

class _ActiveEmergencyScreenState extends ConsumerState<ActiveEmergencyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopEmergency() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop emergency mode?'),
        content: const Text(
          'Your emergency status will no longer be active in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Stop',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(modeProvider.notifier).reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency mode stopped.')),
    );
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  void _showPlaceholder(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _card({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trustees = ref.watch(trusteesProvider);
    final now = DateTime.now();
    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Emergency Active')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Emergency Active',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your emergency status is active in Muhafiz.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.warning_rounded,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _card(
                color: AppColors.primary.withValues(alpha: 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency mode active',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alert status: Alert delivery will be enabled after integration.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Location status: Location sharing will be enabled after location integration.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Started: Today • $timeLabel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trusted contacts',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (trustees.isEmpty)
                      Text(
                        'No trusted contacts are available.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.black.withValues(alpha: 0.65),
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
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency message',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'I need help. Please check on me immediately.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity timeline',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _timelineItem('Emergency mode activated'),
                    _timelineItem('Trusted contacts prepared'),
                    _timelineItem('Location sharing pending integration'),
                    _timelineItem('Alert delivery pending integration'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Stop Emergency Mode',
                onPressed: _stopEmergency,
              ),
              const SizedBox(height: 10),
              OutlineButton(
                text: 'Call Emergency Services',
                icon: Icons.call_outlined,
                onPressed: () => _showPlaceholder(
                  'Emergency calling will be added after integration.',
                ),
              ),
              const SizedBox(height: 10),
              OutlineButton(
                text: 'Share Location',
                icon: Icons.share_location_outlined,
                onPressed: () async {
                  final snapshot = await ref.read(locationServiceProvider).getCurrentLocation();
                  if (!mounted) return;
                  _showPlaceholder(snapshot.statusLabel);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
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
      ),
    );
  }
}

