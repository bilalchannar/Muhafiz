import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const Color primary = Color(0xFFF92A2A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color inputBorder = Color(0x80000000); // 50% black
  static const Color inputFill = Color(0xFFF5F5F5);
  static const Color textHint = Color(0x80000000); // 50% black
  static const Color divider = Color(0x1A000000); // 10% black
  static const Color disabledRed = Color(0x66F92A2A); // 40% red
  static const Color vulnerable = Color(0xFFF2C94C);
  static const Color safe = Color(0xFF4CAF50);
}

class ApiConfig {
  ApiConfig._();
  
  static String get baseUrl {
    // Read from environment variable (supplied via --dart-define=API_URL=...)
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // Default fallback consistent across Android, iOS, and Web
    return 'https://muhafiz-server.onrender.com';
  }
}