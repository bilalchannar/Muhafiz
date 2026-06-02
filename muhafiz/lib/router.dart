import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/screens/splash_screen.dart';
import 'package:muhafiz/screens/welcome_screen.dart';
import 'package:muhafiz/screens/register_screen.dart';
import 'package:muhafiz/screens/details_screen.dart';
import 'package:muhafiz/screens/app_shell.dart';
import 'package:muhafiz/screens/emergency_mode_screen.dart';
import 'package:muhafiz/screens/vulnerable_mode_screen.dart';
import 'package:muhafiz/screens/otp_verification_screen.dart';
import 'package:muhafiz/screens/location_permission_screen.dart';
import 'package:muhafiz/screens/add_trusted_contact_setup_screen.dart';
import 'package:muhafiz/screens/active_emergency_screen.dart';
import 'package:muhafiz/screens/admin_dashboard_screen.dart';
import 'package:muhafiz/screens/battery_optimization_screen.dart';
import 'package:muhafiz/core/secure_storage.dart';
import 'package:muhafiz/providers/auth_provider.dart';
import 'package:muhafiz/providers/user_provider.dart';

class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const register = '/register';
  static const otpVerification = '/otp-verification';
  static const locationPermission = '/location-permission';
  static const addTrustedContactSetup = '/add-trusted-contact-setup';
  static const alertHistory = '/alert-history';
  static const activeEmergency = '/active-emergency';
  static const details = '/details';
  static const home = '/home';
  static const contacts = '/contacts';
  static const settings = '/settings';
  static const vulnerable = '/vulnerable';
  static const emergency = '/emergency';
  static const safetyCenter = '/safety-center';
  static const profile = '/profile';
  static const adminDashboard = '/admin-dashboard';
  static const batteryOptimization = '/battery-optimization';
}

Route<dynamic> onGenerateAppRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.splash:
      return MaterialPageRoute(builder: (_) => const _SplashRedirect());
    case AppRoutes.welcome:
      return MaterialPageRoute(builder: (_) => const WelcomeScreen());
    case AppRoutes.register:
      return MaterialPageRoute(builder: (_) => const RegisterScreen());
    case AppRoutes.otpVerification:
      final phone = settings.arguments as String?;
      return MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(phoneNumber: phone),
      );
    case AppRoutes.locationPermission:
      final args = settings.arguments as Map<String, dynamic>?;
      final fromOnboarding = args?['fromOnboarding'] as bool? ?? false;
      return MaterialPageRoute(
        builder: (_) => LocationPermissionScreen(fromOnboarding: fromOnboarding),
      );
    case AppRoutes.addTrustedContactSetup:
      return MaterialPageRoute(
        builder: (_) => const AddTrustedContactSetupScreen(),
      );
    case AppRoutes.details:
      final phone = settings.arguments as String? ?? '';
      return MaterialPageRoute(builder: (_) => DetailsScreen(phone: phone));
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 0));
    case AppRoutes.safetyCenter:
      return MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 1));
    case AppRoutes.alertHistory:
      return MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 2));
    case AppRoutes.contacts:
      return MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 3));
    case AppRoutes.profile:
      return MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 4));
    case AppRoutes.settings:
      return MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 5));
    case AppRoutes.adminDashboard:
      return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
    case AppRoutes.activeEmergency:
      return MaterialPageRoute(builder: (_) => const ActiveEmergencyScreen());
    case AppRoutes.vulnerable:
      return MaterialPageRoute(builder: (_) => const VulnerableModeScreen());
    case AppRoutes.emergency:
      return MaterialPageRoute(builder: (_) => const EmergencyModeScreen());
    case AppRoutes.batteryOptimization:
      return MaterialPageRoute(builder: (_) => const BatteryOptimizationScreen());
    default:
      return MaterialPageRoute(builder: (_) => const _SplashRedirect());
  }
}

/// Wrapper that checks auth and redirects to appropriate screen
class _SplashRedirect extends ConsumerStatefulWidget {
  const _SplashRedirect();

  @override
  ConsumerState<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends ConsumerState<_SplashRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
    });
  }

  Future<void> _redirect() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Ensure user data is loaded from local storage
    await ref.read(userProvider.notifier).loadUser();

    if (!mounted) return;

    final user = ref.read(userProvider);
    final hasName = user?.name?.isNotEmpty ?? false;
    final hasPhone = user?.phone?.isNotEmpty ?? false;

    // Check secure storage for the sessionId persisted during verifyOtp
    final sessionId = await SecureStorage.getSessionId();
    final hasSessionId = sessionId != null && sessionId.isNotEmpty;

    if (hasName && hasPhone && hasSessionId) {
      // User has completed registration and has a valid token — skip login
      ref.read(authStateProvider.notifier).restoreSession();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      // No valid session — user needs to sign in
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
