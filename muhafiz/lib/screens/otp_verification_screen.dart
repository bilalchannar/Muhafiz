import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/providers/auth_provider.dart';
import 'package:muhafiz/router.dart';
import 'package:muhafiz/widgets/outline_button.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String? phoneNumber;

  const OtpVerificationScreen({super.key, this.phoneNumber});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 30;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isOtpValid => _otpController.text.trim().length == 6;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _otpController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String? _validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP code is required';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Enter the 6-digit code';
    }
    return null;
  }

  void _handleResend() {
    final phone = _resolvedPhoneNumber;
    if (phone.isEmpty) return;
    ref.read(authStateProvider.notifier).sendOtp(phone);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A new OTP request has been started.'),
      ),
    );
    _startTimer();
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Capture navigator before async gaps to avoid BuildContext-across-async lint.
    final nav = Navigator.of(context);

    final phone = _resolvedPhoneNumber;
    if (phone.isNotEmpty) {
      await ref.read(authStateProvider.notifier).verifyOtp(_otpController.text.trim());
      final authState = ref.read(authStateProvider);
      if (authState.status == AuthStatus.error) {
        if (mounted) {
          setState(() {
            _errorMessage = authState.errorMessage;
            _isLoading = false;
          });
        }
        return;
      }

      if (!mounted) return;

      final result = await ref.read(authStateProvider.notifier).checkUser(phone);

      if (result.isNewUser) {
        nav.pushNamedAndRemoveUntil(
          AppRoutes.details,
          (_) => false,
          arguments: phone,
        );
      } else {
        await ref.read(authStateProvider.notifier).loginUser(phone);
        if (mounted) {
          nav.pushNamedAndRemoveUntil(
            AppRoutes.home,
            (_) => false,
          );
        }
      }
    } else {
      nav.pop();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String get _resolvedPhoneNumber {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is String && routeArgs.trim().isNotEmpty) {
      return routeArgs.trim();
    }
    return widget.phoneNumber?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final phoneLabel =
        _resolvedPhoneNumber.isNotEmpty ? _resolvedPhoneNumber : 'your phone number';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Verify your number')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify your number',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the 6-digit code sent to your phone number.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sent to $phoneLabel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  validator: _validateOtp,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'OTP Code',
                    hintText: '------',
                    errorText: _errorMessage,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_secondsLeft > 0)
                      Text(
                        'Resend code in ${_secondsLeft}s',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.black.withValues(alpha: 0.6),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _handleResend,
                        child: const Text('Resend Code'),
                      ),
                    const Spacer(),
                    OutlineButton(
                      text: 'Change phone number',
                      fullWidth: false,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  text: 'Verify and Continue',
                  isLoading: _isLoading,
                  isDisabled: !_isOtpValid,
                  onPressed: _verifyOtp,
                ),
                const SizedBox(height: 12),
                Text(
                  'For your security, never share this code with anyone.',
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
      ),
    );
  }
}

