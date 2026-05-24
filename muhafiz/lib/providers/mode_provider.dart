import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/models/safety_mode_model.dart';
import 'package:muhafiz/repositories/safety_mode_repository.dart';
import 'package:muhafiz/providers/app_service_providers.dart';

final safetyModeRepositoryProvider = Provider<SafetyModeRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SafetyModeRepository(storage);
});

final modeProvider = NotifierProvider<ModeNotifier, SafetyModeModel>(ModeNotifier.new);

// Alias for future consistency
final safetyModeProvider = modeProvider;

class ModeNotifier extends Notifier<SafetyModeModel> {
  @override
  SafetyModeModel build() {
    load();
    return const SafetyModeModel();
  }

  SafetyModeRepository get _repo => ref.read(safetyModeRepositoryProvider);

  Future<void> load() async {
    state = await _repo.loadSafetyMode();
  }

  Future<void> setVulnerable({
    required String message,
    required int intervalMinutes,
  }) async {
    final newState = state.copyWith(
      currentMode: SafetyMode.vulnerable,
      vulnerableActive: true,
      emergencyActive: false,
      vulnerableMessage: message,
      checkInIntervalMinutes: intervalMinutes,
      vulnerableStartedAt: DateTime.now(),
    );
    state = newState;
    await _repo.saveSafetyMode(newState);
  }

  Future<void> setEmergency() async {
    final newState = state.copyWith(
      currentMode: SafetyMode.emergency,
      emergencyActive: true,
      vulnerableActive: false,
      emergencyStartedAt: DateTime.now(),
    );
    state = newState;
    await _repo.saveSafetyMode(newState);
  }

  Future<void> reset() async {
    state = const SafetyModeModel();
    await _repo.saveSafetyMode(state);
  }

  Future<void> updateLastCheckIn() async {
    final newState = state.copyWith(lastCheckInAt: DateTime.now());
    state = newState;
    await _repo.saveSafetyMode(newState);
  }

  Future<void> clear() async {
    state = const SafetyModeModel();
    await _repo.clearSafetyMode();
  }
}
