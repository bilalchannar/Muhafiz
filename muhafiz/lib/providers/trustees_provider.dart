import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/models/trustee_model.dart';
import 'package:muhafiz/providers/app_service_providers.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/repositories/trustee_repository.dart';

final trusteeRepositoryProvider = Provider<TrusteeRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  return TrusteeRepository(storage, firestore, userId: ref.watch(userProvider)?.id);
});

final trusteesProvider = NotifierProvider<TrusteesNotifier, List<TrusteeModel>>(TrusteesNotifier.new);

class TrusteesNotifier extends Notifier<List<TrusteeModel>> {
  @override
  List<TrusteeModel> build() {
    fetchTrustees();
    return [];
  }

  TrusteeRepository get _repo => ref.read(trusteeRepositoryProvider);

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-]'), '');
  }

  Future<void> fetchTrustees() async {
    state = await _repo.loadTrustees();
  }

  Future<void> addTrustee({
    required String name,
    required String phone,
    required String tier,
    String relationship = 'Contact',
  }) async {
    final normalized = _normalizePhone(phone);
    final userPhone = ref.read(userProvider)?.phone;
    if (userPhone != null && _normalizePhone(userPhone) == normalized) {
      throw Exception('You cannot add your own number as a trustee.');
    }

    final exists = state.any((t) => _normalizePhone(t.phone) == normalized);
    if (exists) {
      throw Exception('This phone number is already added.');
    }

    final newTrustee = TrusteeModel(
      id: 'trustee_${DateTime.now().millisecondsSinceEpoch}',
      userId: ref.read(userProvider)?.id ?? '',
      name: name,
      phone: normalized,
      relationship: relationship,
      priority: tier.toLowerCase(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    state = [...state, newTrustee];
    await _repo.saveTrustees(state);
  }

  Future<void> updateTrustee(TrusteeModel updated) async {
    state = [
      for (final t in state)
        if (t.id == updated.id) updated.copyWith(updatedAt: DateTime.now()) else t
    ];
    await _repo.saveTrustees(state);
  }

  Future<void> deleteTrustee(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _repo.saveTrustees(state);
    await _repo.deleteTrustee(id);
  }

  Future<void> clear() async {
    state = [];
    await _repo.clearTrustees();
  }
}
