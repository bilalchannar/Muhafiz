import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muhafiz/core/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const _tagline = 'Your safety companion';
  static const _supportingLine =
      'Emergency help, trusted contacts, and safety alerts in one place.';
  static const _bottomLine = 'Initializing';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildLogo(double size) {
    return SvgPicture.asset(
      'assets/logo/logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (context) =>
          Icon(Icons.shield_rounded, size: size, color: AppColors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final logoSize = (screenWidth * 0.2).clamp(56.0, 88.0);

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, Color(0xFFE11E1E)],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        _buildLogo(logoSize),
                        const SizedBox(height: 20),
                        const Text(
                          'Muhafiz',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _supportingLine,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const Spacer(flex: 3),
                        const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _bottomLine,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(flex: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
