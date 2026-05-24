import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/models/app_settings_model.dart';
import 'package:muhafiz/repositories/settings_repository.dart';
import 'package:muhafiz/providers/app_service_providers.dart';
import 'package:muhafiz/providers/user_provider.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  return SettingsRepository(storage, firestore, userId: ref.watch(userProvider)?.id);
});

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettingsModel>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettingsModel> {
  @override
  AppSettingsModel build() {
    load();
    return const AppSettingsModel();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> load() async {
    state = await _repo.loadSettings();
  }

  Future<void> updateSettings(AppSettingsModel updated) async {
    state = updated;
    await _repo.saveSettings(updated);
  }

  Future<void> updateEmergencyMessage(String message) async {
    final updated = state.copyWith(defaultEmergencyMessage: message);
    state = updated;
    await _repo.saveSettings(updated);
  }

  Future<void> updateCountdown(int seconds) async {
    final updated = state.copyWith(emergencyCountdownSeconds: seconds);
    state = updated;
    await _repo.saveSettings(updated);
  }

  Future<void> updateRepeatInterval(int minutes) async {
    final updated = state.copyWith(alertRepeatIntervalMinutes: minutes);
    state = updated;
    await _repo.saveSettings(updated);
  }

  Future<void> toggleAutoShareLocation(bool enabled) async {
    final updated = state.copyWith(autoShareLocation: enabled);
    state = updated;
    await _repo.saveSettings(updated);
  }

  Future<void> reset() async {
    state = const AppSettingsModel();
    await _repo.clearSettings();
  }
}
