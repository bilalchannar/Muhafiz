import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/providers/auth_provider.dart';
import 'package:muhafiz/router.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final String phone;

  const DetailsScreen({super.key, required this.phone});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _medicalNoteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedGender;
  String? _genderError;

  bool get _isFormValid {
    final nameValid = _nameController.text.trim().length >= 2;
    final genderValid = _selectedGender != null;
    return nameValid && genderValid;
  }

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.phone;
    _nameController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _bloodGroupController.dispose();
    _medicalNoteController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (_genderError != null && _selectedGender != null) {
      setState(() => _genderError = null);
      return;
    }
    setState(() {});
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  void _selectGender(String value) {
    setState(() {
      _selectedGender = value;
      _genderError = null;
    });
  }

  Future<void> _completeRegistration() async {
    final isValid = _formKey.currentState!.validate();
    final genderValid = _selectedGender != null;
    if (!genderValid) {
      setState(() => _genderError = 'Please select a gender');
    }
    if (!isValid || !genderValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();

      // Register user with details
      await ref.read(authStateProvider.notifier).registerUser(
            phone: widget.phone,
            name: name,
            gender: _selectedGender!,
          );

      if (mounted) {
        final authState = ref.read(authStateProvider);
        if (authState.status == AuthStatus.authenticated) {
          Navigator.pushNamed(
            context,
            AppRoutes.locationPermission,
            arguments: {'fromOnboarding': true},
          );
        } else if (authState.status == AuthStatus.error) {
          setState(() {
            _errorMessage = authState.errorMessage;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _genderOption(String label) {
    final isSelected = _selectedGender == label;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isLoading ? null : () => _selectGender(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.inputBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Complete your profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complete your profile',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This information helps Muhafiz personalize your safety experience.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Phone number',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          readOnly: true,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Verified phone number',
                            prefixIcon: Icon(Icons.phone_outlined, size: 22),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Full name',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          validator: _validateName,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: AppColors.black,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Enter your full name',
                            prefixIcon: Icon(Icons.person_outline, size: 22),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Gender',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _genderOption('Male'),
                            const SizedBox(width: 10),
                            _genderOption('Female'),
                            const SizedBox(width: 10),
                            _genderOption('Other'),
                          ],
                        ),
                        if (_genderError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _genderError!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Blood group (optional)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bloodGroupController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'e.g. A+, O-',
                            prefixIcon: Icon(Icons.bloodtype_outlined, size: 22),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Medical note (optional)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _medicalNoteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Add any important medical info',
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        PrimaryButton(
                          text: 'Save and Continue',
                          isLoading: _isLoading,
                          isDisabled: !_isFormValid,
                          onPressed: _completeRegistration,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your profile information helps trusted contacts identify you during emergency alerts.',
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
              ),
            );
          },
        ),
      ),
    );
  }
}
