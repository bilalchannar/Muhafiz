import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/safety_mode_model.dart';
import 'package:muhafiz/providers/app_service_providers.dart';
import 'package:muhafiz/providers/mode_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/providers/alerts_provider.dart';
import 'package:muhafiz/widgets/outline_button.dart';
import 'package:muhafiz/widgets/primary_button.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyModeScreen extends ConsumerStatefulWidget {
  const EmergencyModeScreen({super.key});

  @override
  ConsumerState<EmergencyModeScreen> createState() =>
      _EmergencyModeScreenState();
}

class _EmergencyModeScreenState extends ConsumerState<EmergencyModeScreen> {
  Timer? _timer;
  int _secondsLeft = 5;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['autoStart'] == true) {
        _activateEmergency();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 5;
      _active = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _active = false;
        });
        await _executeEmergencyActivation();
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _executeEmergencyActivation() async {
    await ref.read(modeProvider.notifier).setEmergency();
    final user = ref.read(userProvider);
    final trustees = ref.read(trusteesProvider);
    if (user != null && trustees.isNotEmpty) {
      await ref
          .read(alertDeliveryServiceProvider)
          .createEmergencyAlert(
            userId: user.id,
            message: 'I need help. Please check on me immediately.',
            trustees: trustees,
            includeLocation: true,
          );
      ref.read(alertsProvider.notifier).load();
    }

    // Launch dialer with "15" entered
    try {
      final Uri telUri = Uri(scheme: 'tel', path: '15');
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      }
    } catch (_) {}
  }

  void _activateEmergency() {
    _startCountdown();
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 5;
      _active = false;
    });
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
    ref.read(alertDeliveryServiceProvider).stopRealtimeService();
    await ref.read(modeProvider.notifier).reset();
    if (!mounted) return;
    _cancelCountdown();
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
    final modeState = ref.watch(modeProvider);
    final isEmergencyActive = modeState.currentMode == SafetyMode.emergency;
    final contactsCount = trustees.length;

    final alertStatus = isEmergencyActive
        ? 'Emergency active'
        : _active
        ? 'Ready to send'
        : 'Not sent';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Emergency Mode'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Emergency Mode',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use this only when you need immediate help.',
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
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isEmergencyActive
                                ? AppColors.primary
                                : AppColors.safe,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEmergencyActive
                              ? 'Emergency mode is active'
                              : 'Emergency mode is idle',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isEmergencyActive
                                ? AppColors.primary
                                : AppColors.safe,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Alert status: $alertStatus',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEmergencyActive
                          ? 'Location status: Live sharing active'
                          : 'Location status: Enabled (shares on active SOS)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Trusted contacts: $contactsCount',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.65),
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
                    if (isEmergencyActive) ...[
                      const Text(
                        'Emergency Mode is currently running.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        text: 'Stop Emergency Mode',
                        onPressed: _stopEmergency,
                      ),
                    ] else ...[
                      Text(
                        _active
                            ? 'Emergency alert will activate in $_secondsLeft seconds'
                            : 'Emergency alert will activate in 5 seconds',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        text: 'Activate Emergency',
                        onPressed: _active ? null : _activateEmergency,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This will start emergency mode in the app.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      if (_active) ...[
                        const SizedBox(height: 12),
                        OutlineButton(
                          text: 'Cancel countdown',
                          onPressed: _cancelCountdown,
                        ),
                      ],
                    ],
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
