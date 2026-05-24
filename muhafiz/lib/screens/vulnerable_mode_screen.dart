import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/safety_mode_model.dart';
import 'package:muhafiz/providers/app_service_providers.dart';
import 'package:muhafiz/providers/mode_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/providers/alerts_provider.dart';
import 'package:muhafiz/widgets/outline_button.dart';
import 'package:muhafiz/widgets/primary_button.dart';

class VulnerableModeScreen extends ConsumerStatefulWidget {
  const VulnerableModeScreen({super.key});

  @override
  ConsumerState<VulnerableModeScreen> createState() =>
      _VulnerableModeScreenState();
}

class _VulnerableModeScreenState extends ConsumerState<VulnerableModeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  int _interval = 30;
  bool _initialized = false;

  bool get _isFormValid {
    final text = _messageController.text.trim();
    return text.isNotEmpty && text.length <= 160;
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _initializeFromState(SafetyModeModel state) {
    if (_initialized) return;
    if (state.currentMode == SafetyMode.vulnerable) {
      _messageController.text = state.vulnerableMessage;
      _interval = state.checkInIntervalMinutes;
    }
    if (_messageController.text.isEmpty) {
      _messageController.text = 'I am travelling to an unfamiliar location. Please keep an eye on my status.';
    }
    if (_interval == 0) {
      _interval = 30;
    }
    _initialized = true;
  }

  String? _validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Safety message is required';
    }
    if (value.trim().length > 160) {
      return 'Message should be under 160 characters';
    }
    return null;
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(modeProvider.notifier).setVulnerable(
          message: _messageController.text.trim(),
          intervalMinutes: _interval,
        );

    final user = ref.read(userProvider);
    final trustees = ref.read(trusteesProvider);
    if (user != null && trustees.isNotEmpty) {
      await ref.read(alertDeliveryServiceProvider).createVulnerableSession(
            userId: user.id,
            message: _messageController.text.trim(),
            checkInMinutes: _interval,
            trustees: trustees,
            includeLocation: true,
          );
      ref.read(alertsProvider.notifier).load();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Protective Mode activated'),
        backgroundColor: AppColors.vulnerable,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _stopVulnerable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop Protective Mode?'),
        content: const Text(
          'Muhafiz will stop monitoring this safety session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Stop',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    ref.read(alertDeliveryServiceProvider).stopRealtimeService();
    await ref.read(modeProvider.notifier).reset();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _card({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  Widget _intervalChip(int minutes, bool selected) {
    return ChoiceChip(
      label: Text(
        minutes >= 60 ? '${minutes ~/ 60} hour' : '$minutes min',
      ),
      selected: selected,
      selectedColor: AppColors.vulnerable.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.black : AppColors.black,
      ),
      onSelected: (_) => setState(() => _interval = minutes),
      side: BorderSide(
        color: selected ? AppColors.vulnerable : AppColors.divider,
      ),
      backgroundColor: AppColors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeState = ref.watch(modeProvider);
    final trustees = ref.watch(trusteesProvider);
    final isActive = modeState.currentMode == SafetyMode.vulnerable;
    _initializeFromState(modeState);

    final contactsCount = trustees.length;
    final intervalLabel = _interval >= 60
        ? '${_interval ~/ 60} hour'
        : '$_interval min';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Protective Mode')),
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
                  'Protective Mode',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use this when travelling alone, going home late, or entering an unsafe place.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),

                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.vulnerable
                                  : AppColors.safe,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isActive
                                ? 'Protective Mode is active'
                                : 'Protective Mode is idle',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? AppColors.vulnerable
                                  : AppColors.safe,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check-in status: ${isActive ? 'Active check-ins' : 'Not active'}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.black.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selected interval: $intervalLabel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.black.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Trusted contacts: $contactsCount',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.black.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Safety message',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  maxLines: 3,
                  maxLength: 160,
                  validator: _validateMessage,
                  decoration: const InputDecoration(
                    labelText: 'Safety message',
                    hintText: 'Example: I am travelling to an unfamiliar location...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Check-in interval',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _intervalChip(15, _interval == 15),
                    _intervalChip(30, _interval == 30),
                    _intervalChip(60, _interval == 60),
                    _intervalChip(120, _interval == 120),
                  ],
                ),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Message Preview',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🟡 - Message for {name}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _messageController.text.trim().isEmpty 
                                  ? 'I am travelling to an unfamiliar location. Please keep an eye on my status.' 
                                  : _messageController.text.trim(),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Location: https://maps.google.com/?q=...',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '(Muhafiz: This is an automated message from Protective Mode indicating the user is in a potentially unsafe situation.)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppColors.black.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  text: isActive ? 'Update Protective Mode' : 'Start Protective Mode',
                  isDisabled: !_isFormValid,
                  onPressed: _activate,
                ),
                if (isActive) ...[
                  const SizedBox(height: 10),
                  OutlineButton(
                    text: 'Stop Protective Mode',
                    onPressed: _stopVulnerable,
                    foregroundColor: AppColors.primary,
                    borderColor: AppColors.primary,
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onMessageChanged() {
    setState(() {});
  }
}
