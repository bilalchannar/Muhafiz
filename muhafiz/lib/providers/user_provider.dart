import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/models/user_model.dart';
import 'package:muhafiz/repositories/user_repository.dart';
import 'package:muhafiz/providers/app_service_providers.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  return UserRepository(storage, firestore);
});

final userProvider = NotifierProvider<UserNotifier, UserModel?>(UserNotifier.new);

class UserNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() {
    loadUser();
    return null;
  }

  UserRepository get _repo => ref.read(userRepositoryProvider);

  Future<void> loadUser() async {
    state = await _repo.loadUser();
  }

  Future<void> saveOnboarding({
    String? id,
    required String name,
    required String phone,
    required String gender,
  }) async {
    final resolvedId = id ?? state?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final user = (state ?? const UserModel(id: '')).copyWith(
      id: resolvedId,
      name: name,
      phone: phone,
      gender: gender,
      createdAt: state?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    state = user;
    await _repo.saveUser(user);
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? gender,
    String? bloodGroup,
    String? medicalNote,
  }) async {
    if (state == null) return;
    
    final user = state!.copyWith(
      name: name ?? state!.name,
      phone: phone ?? state!.phone,
      gender: gender ?? state!.gender,
      bloodGroup: bloodGroup ?? state!.bloodGroup,
      medicalNote: medicalNote ?? state!.medicalNote,
      updatedAt: DateTime.now(),
    );
    state = user;
    await _repo.saveUser(user);
  }

  Future<void> updateSettings({
    required String name,
    required String phone,
    required String gender,
  }) async {
    await updateProfile(name: name, phone: phone, gender: gender);
  }

  Future<void> clear() async {
    final id = state?.id;
    state = null;
    await _repo.clearUser(id);
  }

  Future<void> setUser(UserModel user) async {
    state = user;
    await _repo.saveUser(user);
  }
}
