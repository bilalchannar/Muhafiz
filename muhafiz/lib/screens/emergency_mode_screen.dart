import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/models/safety_mode_model.dart';
import 'package:muhafiz/models/alert_model.dart';
import 'package:muhafiz/providers/app_service_providers.dart';
import 'package:muhafiz/providers/mode_provider.dart';
import 'package:muhafiz/providers/trustees_provider.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/providers/alerts_provider.dart';
import 'package:muhafiz/widgets/primary_button.dart';
import 'package:url_launcher/url_launcher.dart';

enum SOSStatus {
  idle,
  countdown,
  gettingLocation,
  savingAlert,
  notifyingContacts,
  completed,
  failed,
}

class EmergencyModeScreen extends ConsumerStatefulWidget {
  const EmergencyModeScreen({super.key});

  @override
  ConsumerState<EmergencyModeScreen> createState() => _EmergencyModeScreenState();
}

class _EmergencyModeScreenState extends ConsumerState<EmergencyModeScreen>
    with TickerProviderStateMixin {
  Timer? _countdownTimer;
  int _secondsLeft = 5;
  SOSStatus _sosStatus = SOSStatus.idle;
  String? _errorMessage;
  bool _offlineMode = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['autoStart'] == true) {
        _activateEmergency();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _activateEmergency() {
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _pulseController.repeat(reverse: true);
    
    // Initial haptic impact
    HapticFeedback.heavyImpact();

    setState(() {
      _secondsLeft = 5;
      _sosStatus = SOSStatus.countdown;
      _offlineMode = false;
      _errorMessage = null;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      
      // Haptic tick on every second
      HapticFeedback.lightImpact();

      if (_secondsLeft <= 1) {
        timer.cancel();
        _pulseController.stop();
        setState(() {
          _secondsLeft = 0;
        });
        await _executeEmergencyActivation();
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _pulseController.stop();
    HapticFeedback.mediumImpact();
    setState(() {
      _secondsLeft = 5;
      _sosStatus = SOSStatus.idle;
    });
  }

  Future<void> _executeEmergencyActivation() async {
    // 1. Differentiate states: Getting Location
    setState(() {
      _sosStatus = SOSStatus.gettingLocation;
    });
    
    // Intense vibration to alert activation
    HapticFeedback.vibrate();

    final user = ref.read(userProvider);
    final trustees = ref.read(trusteesProvider);

    if (user == null || trustees.isEmpty) {
      setState(() {
        _sosStatus = SOSStatus.failed;
        _errorMessage = 'No user profile or trusted contacts found. Please register contacts first.';
      });
      return;
    }

    double? lat;
    double? lng;
    
    try {
      final loc = await ref.read(locationServiceProvider).getCurrentLocation();
      lat = loc.latitude;
      lng = loc.longitude;
    } catch (_) {
      // Gracefully continue with null location (offline or disabled)
    }

    // 2. Differentiate states: Saving Alert
    setState(() {
      _sosStatus = SOSStatus.savingAlert;
    });

    final String messageWithUser = 'Emergency SOS Alert from ${user.name ?? "User"}: I need help. Please check on me immediately.';
    String finalMessage = messageWithUser;
    if (lat != null && lng != null) {
      finalMessage += '\nLocation: https://maps.google.com/?q=$lat,$lng';
    } else {
      finalMessage += '\nLocation: Unavailable (GPS offline)';
    }

    final alert = AlertModel(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      type: AlertType.emergency,
      status: AlertStatus.pending,
      message: messageWithUser,
      latitude: lat,
      longitude: lng,
      sentToTrusteeIds: trustees.map((t) => t.id).toList(),
      createdAt: DateTime.now(),
    );

    // Save pending state locally
    await ref.read(alertDeliveryServiceProvider).sendEmergencyAlert(alert);
    ref.read(alertsProvider.notifier).load();

    // 3. Differentiate states: Notifying Contacts
    setState(() {
      _sosStatus = SOSStatus.notifyingContacts;
    });

    final phones = trustees.map((t) => t.phone).toList();
    final success = await ref.read(alertDeliveryServiceProvider).sendMassMessage(phones, finalMessage);

    // Update alert status
    final updatedAlert = alert.copyWith(
      status: success ? AlertStatus.delivered : AlertStatus.failed,
      updatedAt: DateTime.now(),
    );
    await ref.read(alertDeliveryServiceProvider).sendEmergencyAlert(updatedAlert);
    ref.read(alertsProvider.notifier).load();

    setState(() {
      _sosStatus = success ? SOSStatus.completed : SOSStatus.failed;
      _offlineMode = !success;
    });

    // Auto-update safety mode active state
    await ref.read(modeProvider.notifier).setEmergency();

    // Trigger phone dialer to 15 (Local emergency helper)
    try {
      final Uri telUri = Uri(scheme: 'tel', path: '15');
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      }
    } catch (_) {}
  }

  Future<void> _stopEmergency() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop emergency mode?'),
        content: const Text(
          'Your emergency status will no longer be active in the app.',
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
    
    HapticFeedback.mediumImpact();
    ref.read(alertDeliveryServiceProvider).stopRealtimeService();
    await ref.read(modeProvider.notifier).reset();
    setState(() {
      _sosStatus = SOSStatus.idle;
      _offlineMode = false;
    });
  }

  Future<void> _sendOfflineSMS() async {
    final trustees = ref.read(trusteesProvider);
    if (trustees.isEmpty) return;
    
    final phones = trustees.map((t) => t.phone).toList();
    final message = 'Emergency SOS Alert! I need help immediately. My mobile data/internet connection is offline.';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phones.join(','),
      queryParameters: <String, String>{
        'body': message,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open default messaging app.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open SMS app.')),
      );
    }
  }

  Widget _buildCountdownUI() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF92A2A),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'EMERGENCY SOS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Starting SOS Alert and notifying all trusted contacts...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 60),
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_secondsLeft',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFF92A2A),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _cancelCountdown,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'CANCEL SOS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivatingStepperUI() {
    Widget stepTile(String title, String status) {
      Widget leadingWidget;
      Color textColor;
      FontWeight fontWeight;

      switch (status) {
        case 'success':
          leadingWidget = const Icon(Icons.check_circle_rounded, color: AppColors.safe, size: 24);
          textColor = AppColors.black;
          fontWeight = FontWeight.w600;
          break;
        case 'failed':
          leadingWidget = const Icon(Icons.error_rounded, color: AppColors.primary, size: 24);
          textColor = AppColors.primary;
          fontWeight = FontWeight.w800;
          break;
        case 'loading':
          leadingWidget = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
          );
          textColor = AppColors.black;
          fontWeight = FontWeight.w800;
          break;
        case 'idle':
        default:
          leadingWidget = const Icon(Icons.circle_outlined, color: Colors.grey, size: 24);
          textColor = Colors.black54;
          fontWeight = FontWeight.w500;
          break;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            leadingWidget,
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }

    final gpsStatus = _sosStatus == SOSStatus.gettingLocation
        ? 'loading'
        : (_sosStatus.index > SOSStatus.gettingLocation.index ? 'success' : 'idle');

    final saveStatus = _sosStatus == SOSStatus.savingAlert
        ? 'loading'
        : (_sosStatus.index > SOSStatus.savingAlert.index ? 'success' : 'idle');

    final notifyStatus = _sosStatus == SOSStatus.notifyingContacts
        ? 'loading'
        : (_sosStatus == SOSStatus.completed
            ? 'success'
            : (_sosStatus == SOSStatus.failed ? 'failed' : 'idle'));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(_sosStatus == SOSStatus.completed
            ? 'SOS Alert Sent'
            : (_sosStatus == SOSStatus.failed ? 'SOS Alert Failed' : 'Sending SOS...')),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SOS Dispatch Progress',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    stepTile('Getting GPS Location...', gpsStatus),
                    const Divider(height: 1),
                    stepTile('Saving safety alert record...', saveStatus),
                    const Divider(height: 1),
                    stepTile('Notifying trusted contacts via WhatsApp...', notifyStatus),
                  ],
                ),
              ),
              if (_sosStatus == SOSStatus.completed) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'SOS Alert Dispatched',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your location and alert details have been saved, and your contacts have been notified successfully.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _sosStatus = SOSStatus.idle;
                          });
                        },
                        child: const Text('Dismiss', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
              if (_sosStatus == SOSStatus.failed) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColors.primary, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Notification Failed',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Unable to notify some or all contacts via the server/WhatsApp. You may be offline or the server might be unreachable.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: _sendOfflineSMS,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sms_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Send Offline SMS Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _sosStatus = SOSStatus.idle;
                          });
                        },
                        child: const Text('Close', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainUI(bool isEmergencyActive, List trustees) {
    final contactsCount = trustees.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emergency Mode',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use this only when you need immediate help.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          
          if (_offlineMode) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Offline Mode Fallback',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'WhatsApp server notifications failed. This usually means you are offline or have no active mobile data. Send an offline backup SMS directly.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: 'Send Offline SMS Now',
                    onPressed: _sendOfflineSMS,
                  ),
                ],
              ),
            ),
          ],

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isEmergencyActive ? AppColors.primary : AppColors.safe,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEmergencyActive ? 'Emergency mode is active' : 'Emergency mode is idle',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isEmergencyActive ? AppColors.primary : AppColors.safe,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Alert status: ${isEmergencyActive ? 'SOS Alerts Dispatched' : 'Not active'}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.black.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isEmergencyActive
                      ? 'Location status: Live sharing active'
                      : 'Location status: Enabled (shares on active SOS)',
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
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEmergencyActive) ...[
                  const Text(
                    'SOS Broadcast Active',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your contacts are monitoring your status. Tap below once you are safe to stop alerts.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    text: 'Stop Emergency Mode',
                    onPressed: _stopEmergency,
                  ),
                ] else ...[
                  const Text(
                    'Trigger Emergency SOS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Initiates a 5-second countdown with haptic feedback, allowing you to abort if triggered accidentally.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.black.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    text: 'Activate Emergency',
                    onPressed: trustees.isEmpty ? null : _activateEmergency,
                  ),
                  if (trustees.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '⚠️ You must add at least one trusted contact from the contacts tab to use emergency alerts.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trustees = ref.watch(trusteesProvider);
    final modeState = ref.watch(modeProvider);
    final isEmergencyActive = modeState.currentMode == SafetyMode.emergency;

    // Determine overlay layout
    if (_sosStatus == SOSStatus.countdown) {
      return Scaffold(
        body: _buildCountdownUI(),
      );
    }

    if (_sosStatus == SOSStatus.gettingLocation ||
        _sosStatus == SOSStatus.savingAlert ||
        _sosStatus == SOSStatus.notifyingContacts ||
        _sosStatus == SOSStatus.completed ||
        _sosStatus == SOSStatus.failed) {
      return _buildActivatingStepperUI();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Emergency Mode'), centerTitle: true),
      body: SafeArea(
        child: _buildMainUI(isEmergencyActive, trustees),
      ),
    );
  }
}
