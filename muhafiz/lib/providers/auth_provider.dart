import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/providers/user_provider.dart';
import 'package:muhafiz/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

enum AuthStatus { unknown, unauthenticated, authenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  AuthState({required this.status, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UserCheckResult {
  final bool isNewUser;
  UserCheckResult({required this.isNewUser});
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState(status: AuthStatus.unknown);
  }

  AuthService get _authService => ref.read(authServiceProvider);

  Future<UserCheckResult> checkUser(String phone) async {
    // Check local user first for consistency with previous behavior
    final user = ref.read(userProvider);
    final userExistsLocally = user != null &&
        (user.phone?.isNotEmpty ?? false) &&
        (user.name?.isNotEmpty ?? false);

    if (userExistsLocally) {
      return UserCheckResult(isNewUser: false);
    }

    // Check service (future Firebase/Firestore check)
    final exists = await _authService.checkUserExists(phone);
    return UserCheckResult(isNewUser: !exists);
  }

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authService.sendOtp(phone);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authService.verifyOtp(smsCode);
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> registerUser({
    required String phone,
    required String name,
    required String gender,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _authService.registerUser(
        phone: phone,
        name: name,
        gender: gender,
      );

      await ref.read(userProvider.notifier).saveOnboarding(
            id: user.id,
            name: user.name ?? name,
            phone: user.phone ?? phone,
            gender: user.gender ?? gender,
          );

      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> loginUser(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _authService.loginUser(phone);
      
      // Save the fetched user locally
      await ref.read(userProvider.notifier).setUser(user);

      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    await ref.read(userProvider.notifier).clear();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Called on app startup when a persisted sessionId is found in secure storage.
  void restoreSession() {
    state = state.copyWith(status: AuthStatus.authenticated);
  }
}
