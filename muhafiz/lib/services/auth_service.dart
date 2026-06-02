import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/core/secure_storage.dart';
import 'package:muhafiz/models/user_model.dart';
import 'package:muhafiz/services/firestore_service.dart';
import 'package:muhafiz/services/notification_service.dart';

class AuthService {
  AuthService() : _firestore = FirestoreService();

  final FirestoreService _firestore;
  String? _currentPhone;

  String get _baseUrl => ApiConfig.baseUrl;

  Future<bool> checkUserExists(String phone) async {
    final users = await _firestore.queryCollection('users');
    return users.any((user) => user['phone']?.toString() == phone);
  }

  Future<String> sendOtp(String phone) async {
    _currentPhone = phone;

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/reqOTP'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return 'otp_sent';
      } else {
        throw Exception(data['message'] ?? 'Failed to send OTP');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    if (_currentPhone == null) {
      throw Exception('OTP session expired. Please request a new code.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verifyOTP'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': _currentPhone, 'otp': smsCode}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final sessionId = data['sessionId'];
        if (sessionId != null) {
          await SecureStorage.saveSessionId(sessionId);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('bg_session_id', sessionId);
        }
      } else {
        throw Exception(data['message'] ?? 'Invalid OTP');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<UserModel> registerUser({
    required String phone,
    required String name,
    required String gender,
  }) async {
    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';

    final user = UserModel(
      id: uid,
      phone: phone,
      name: name,
      gender: gender,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final accessToken =
        'access_token_${phone}_${DateTime.now().millisecondsSinceEpoch}';
    final refreshToken =
        'refresh_token_${phone}_${DateTime.now().millisecondsSinceEpoch}';
    await SecureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    await _firestore.upsertDocument('users', uid, {
      ...user.toJson(),
      'fcmToken': await NotificationService.instance.getFcmToken(),
    });

    return user;
  }

  Future<UserModel> loginUser(String phone) async {
    final users = await _firestore.queryCollection('users');
    final userDoc = users.firstWhere(
      (u) => u['phone']?.toString() == phone,
      orElse: () => throw Exception('User not found in database'),
    );
    final user = UserModel.fromJson(userDoc);

    final accessToken =
        'access_token_${phone}_${DateTime.now().millisecondsSinceEpoch}';
    final refreshToken =
        'refresh_token_${phone}_${DateTime.now().millisecondsSinceEpoch}';
    await SecureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return user;
  }

  Future<void> logout() async {
    await SecureStorage.clear();
  }
}
