import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/providers/auth_provider.dart';
import 'package:muhafiz/router.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPhoneValid = false;

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_updatePhoneValidity);
  }

  @override
  void dispose() {
    _mobileController.removeListener(_updatePhoneValidity);
    _mobileController.dispose();
    super.dispose();
  }

  void _updatePhoneValidity() {
    final value = _mobileController.text.trim();
    final isValid = RegExp(r'^\d{10}$').hasMatch(value);
    if (isValid != _isPhoneValid) {
      setState(() => _isPhoneValid = isValid);
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{10}$').hasMatch(cleaned)) {
      return 'Enter a valid 10-digit number';
    }
    return null;
  }

  Future<void> _checkUserAndProceed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = '+92${_mobileController.text.trim()}';

      await ref.read(authStateProvider.notifier).sendOtp(phone);

      if (!mounted) return;

      final authState = ref.read(authStateProvider);

      if (authState.status == AuthStatus.error) {
        setState(() {
          _errorMessage = authState.errorMessage ?? 'Failed to send OTP';
        });
        return;
      }

      // Always go to OTP verification first
      Navigator.pushNamed(context, AppRoutes.otpVerification, arguments: phone);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        // Logo
                        SvgPicture.asset(
                          'assets/logo/logo.svg',
                          width: 56,
                          height: 56,
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Enter your phone number',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'We\'ll use this number to verify your identity and connect your safety account.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Phone input
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.number,
                          validator: _validatePhone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: AppColors.black,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            prefixText: '+92 ',
                            prefixStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                            prefixIcon: Icon(Icons.phone_outlined, size: 22),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'A verification code will be sent to this number.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.black.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 18,
                          child: AnimatedOpacity(
                            opacity: _errorMessage == null ? 0 : 1,
                            duration: const Duration(milliseconds: 150),
                            child: Text(
                              _errorMessage ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        PrimaryButton(
                          text: 'Continue',
                          isLoading: _isLoading,
                          isDisabled: !_isPhoneValid,
                          onPressed: _checkUserAndProceed,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
