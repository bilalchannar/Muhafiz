import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/services/firebase_bootstrap.dart';
import 'package:muhafiz/services/notification_service.dart';
import 'package:muhafiz/services/background_service.dart';
import 'package:muhafiz/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely)
  try {
    await FirebaseBootstrap.ensureInitialized();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Platform-specific services
  if (!kIsWeb) {
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }

    try {
      await initializeBackgroundService();
    } catch (e) {
      debugPrint('Background service initialization failed: $e');
    }

    // Set status bar style (mobile only)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  runApp(const ProviderScope(child: MuhafizApp()));
}

class MuhafizApp extends StatelessWidget {
  const MuhafizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muhafiz',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: onGenerateAppRoute,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.white,
        fontFamily: 'Inter',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputFill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          labelStyle: const TextStyle(
            color: AppColors.inputBorder,
            fontFamily: 'Inter',
          ),
          hintStyle: TextStyle(
            color: AppColors.black.withValues(alpha: 0.38),
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}
