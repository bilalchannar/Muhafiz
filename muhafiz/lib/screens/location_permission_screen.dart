import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/providers/app_service_providers.dart';
import 'package:muhafiz/router.dart';
import 'package:muhafiz/widgets/outline_button.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  final bool fromOnboarding;
  
  const LocationPermissionScreen({
    super.key,
    this.fromOnboarding = false,
  });

  @override
  ConsumerState<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends ConsumerState<LocationPermissionScreen> {
  bool _requesting = false;

  Future<void> _allowLocation() async {
    setState(() => _requesting = true);
    final granted = await ref.read(locationServiceProvider).requestPermission();
    final snapshot = granted
        ? await ref.read(locationServiceProvider).getCurrentLocation()
        : await ref.read(locationServiceProvider).getLocationStatus();

    if (!mounted) return;
    setState(() => _requesting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snapshot.statusLabel)),
    );

    if (granted) {
      _navigateNext();
    }
  }

  void _handleNotNow() {
    _navigateNext();
  }

  void _navigateNext() {
    if (widget.fromOnboarding) {
      Navigator.pushReplacementNamed(context, AppRoutes.addTrustedContactSetup);
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Enable location access')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    Icons.my_location_rounded,
                    color: AppColors.primary,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enable location access',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Muhafiz uses your location to help trusted contacts find you during emergencies.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              _BenefitRow(
                icon: Icons.share_location_outlined,
                text: 'Share your live location during emergency mode.',
              ),
              const SizedBox(height: 10),
              _BenefitRow(
                icon: Icons.people_outline,
                text: 'Help trusted contacts reach you faster.',
              ),
              const SizedBox(height: 10),
              _BenefitRow(
                icon: Icons.shield_outlined,
                text: 'Improve safety check-ins during protective mode.',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Your location is shared only during safety workflows and only with your trusted contacts.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Allow Location Access',
                isLoading: _requesting,
                onPressed: _allowLocation,
              ),
              const SizedBox(height: 10),
              OutlineButton(
                text: 'Not Now',
                onPressed: _handleNotNow,
              ),
              const SizedBox(height: 12),
              Text(
                'You can change this later from Settings.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.black.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
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

