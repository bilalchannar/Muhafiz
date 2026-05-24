import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/models/alert_model.dart';
import 'package:muhafiz/repositories/alert_repository.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/services/local_storage_service.dart';
import 'package:muhafiz/services/firestore_service.dart';

final storageServiceProvider = Provider<LocalStorageService>((ref) => LocalStorageService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  return AlertRepository(storage, firestore, userId: ref.watch(userProvider)?.id);
});

final alertsProvider = NotifierProvider<AlertsNotifier, List<AlertModel>>(AlertsNotifier.new);

class AlertsNotifier extends Notifier<List<AlertModel>> {
  @override
  List<AlertModel> build() {
    load();
    return [];
  }

  AlertRepository get _repo => ref.read(alertRepositoryProvider);

  Future<void> load() async {
    state = await _repo.loadAlerts();
  }

  Future<void> addAlert({
    required AlertType type,
    required String message,
    double? lat,
    double? lng,
    String? address,
    List<String> trusteeIds = const [],
  }) async {
    final newAlert = AlertModel(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      userId: ref.read(userProvider)?.id ?? '',
      type: type,
      status: AlertStatus.sent,
      message: message,
      latitude: lat,
      longitude: lng,
      address: address,
      sentToTrusteeIds: trusteeIds,
      createdAt: DateTime.now(),
    );
    state = [newAlert, ...state];
    await _repo.saveAlerts(state);
  }

  Future<void> updateAlertStatus(String id, AlertStatus status) async {
    state = [
      for (final a in state)
        if (a.id == id) a.copyWith(status: status, updatedAt: DateTime.now()) else a
    ];
    await _repo.saveAlerts(state);
  }

  Future<void> clear() async {
    state = [];
    await _repo.clearAlerts();
  }
}
