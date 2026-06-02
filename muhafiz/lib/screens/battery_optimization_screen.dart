import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class BatteryOptimizationScreen extends StatelessWidget {
  const BatteryOptimizationScreen({super.key});

  Widget _stepCard({required String number, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
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
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.black.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Background Activity Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.battery_saver_rounded,
                    color: AppColors.primary,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Keep background monitor active',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'To send emergency alerts and updates in the background, your OS battery optimization settings must be configured correctly.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isAndroid ? 'Android Configuration Guide' : 'iOS Configuration Guide',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: isAndroid
                      ? [
                          _stepCard(
                            number: '1',
                            title: 'Open App Settings',
                            description: 'Tap the button at the bottom to open the system settings screen for Muhafiz.',
                          ),
                          _stepCard(
                            number: '2',
                            title: 'Select App Battery Usage',
                            description: 'Scroll down to locate and tap on "Battery" or "App Battery Usage".',
                          ),
                          _stepCard(
                            number: '3',
                            title: 'Set to Unrestricted',
                            description: 'Change the optimization setting from "Optimized" to "Unrestricted" (or "Don\'t optimize") to prevent the app from being closed in the background.',
                          ),
                        ]
                      : [
                          _stepCard(
                            number: '1',
                            title: 'Allow Always Location Access',
                            description: 'Go to Settings -> Muhafiz -> Location and check "Always". This is required for emergency background GPS transmission.',
                          ),
                          _stepCard(
                            number: '2',
                            title: 'Enable Background App Refresh',
                            description: 'Toggle on the "Background App Refresh" switch under the app settings page.',
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Open System Settings',
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Changes take effect immediately.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.black.withValues(alpha: 0.5),
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
