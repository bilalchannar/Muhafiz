import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/router.dart';
import 'package:muhafiz/widgets/outline_button.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class AddTrustedContactSetupScreen extends ConsumerStatefulWidget {
  const AddTrustedContactSetupScreen({super.key});

  @override
  ConsumerState<AddTrustedContactSetupScreen> createState() =>
      _AddTrustedContactSetupScreenState();
}

class _AddTrustedContactSetupScreenState
    extends ConsumerState<AddTrustedContactSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+92');
  String _relationship = 'Friend';
  String _priority = 'Primary';
  bool _isSaving = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateValidity);
    _phoneController.addListener(_updateValidity);
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateValidity);
    _phoneController.removeListener(_updateValidity);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _updateValidity() {
    final nameOk = _nameController.text.trim().isNotEmpty;
    final cleaned = _phoneController.text.replaceAll(RegExp(r'[\s\-]'), '');
    final phoneOk = RegExp(r'^\+92\d{10}$').hasMatch(cleaned);
    final nextValid = nameOk && phoneOk;
    if (nextValid != _isFormValid) {
      setState(() => _isFormValid = nextValid);
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^\+92\d{10}$').hasMatch(cleaned)) {
      return 'Enter valid number like +923001234567';
    }
    return null;
  }

  Future<void> _addContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(trusteesProvider.notifier).addTrustee(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            tier: _priority,
          );
      // TODO: Persist relationship and priority once model supports it.

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trusted contact added.')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _skipForNow() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (_) => false,
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Add a trusted contact')),
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
                  'Add a trusted contact',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Trusted contacts receive your emergency and protective mode alerts.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  child: const Text(
                    'For better safety, add at least one trusted contact before using emergency mode.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        validator: _validateName,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: '+923001234567',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _relationship,
                        items: const [
                          'Father',
                          'Mother',
                          'Brother',
                          'Sister',
                          'Friend',
                          'Guardian',
                          'Other',
                        ]
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _relationship = value);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Relationship'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        items: const [
                          'Primary',
                          'Secondary',
                          'Backup',
                        ]
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _priority = value);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Priority'),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: 'Add Contact',
                        isLoading: _isSaving,
                        isDisabled: !_isFormValid,
                        onPressed: _addContact,
                      ),
                      const SizedBox(height: 10),
                      OutlineButton(
                        text: 'Skip for Now',
                        onPressed: _skipForNow,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can add or edit trusted contacts later from the Contacts tab.',
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
