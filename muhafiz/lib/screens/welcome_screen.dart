import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/router.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final illustrationSize = (screenWidth * 0.6).clamp(180.0, 320.0);

            return Column(
              children: [
                // Top bar with logo
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/logo/logo.svg',
                        width: 36,
                        height: 36,
                      ),
                    ],
                  ),
                ),

                // Illustration area
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Image.asset(
                      'assets/avatars/women-icon.png',
                      width: illustrationSize,
                      height: illustrationSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Bottom content
                Expanded(
                  flex: 6,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome to Muhafiz',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your safety companion.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.black.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _BenefitRow(
                          icon: Icons.warning_amber_rounded,
                          text: 'Instant Emergency Alerts',
                        ),
                        const SizedBox(height: 10),
                        _BenefitRow(
                          icon: Icons.people_outline_rounded,
                          text: 'Trusted Contact Support',
                        ),
                        const SizedBox(height: 10),
                        _BenefitRow(
                          icon: Icons.location_on_outlined,
                          text: 'Location-Based Safety',
                        ),
                        const Spacer(),
                        PrimaryButton(
                          text: 'Get Started',
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.register,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your data stays protected and is only used during app usage.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            height: 1.4,
                            color: AppColors.black.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
