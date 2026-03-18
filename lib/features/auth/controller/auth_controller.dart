// lib/features/auth/controller/auth_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/user_role.dart';
import '../../../services/auth_service.dart';

class AuthState {
  final bool isLoggedIn;
  final UserRole? role;
  final String? fullName;
  final int? userId;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.role,
    this.fullName,
    this.userId,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    UserRole? role,
    String? fullName,
    int? userId,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        role:       role       ?? this.role,
        fullName:   fullName   ?? this.fullName,
        userId:     userId     ?? this.userId,
        isLoading:  isLoading  ?? this.isLoading,
        error:      error,
      );
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  /// Restore session khi mở app
  Future<bool> restoreSession() async {
    final ok = await AuthService.instance.restoreSession();
    if (ok) {
      state = state.copyWith(
        isLoggedIn: true,
        role:       AuthService.instance.currentRole,
        fullName:   AuthService.instance.currentFullName,
        userId:     AuthService.instance.currentUserId,
      );
    }
    return ok;
  }

  /// Login
  Future<String?> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final err = await AuthService.instance.login(
      username:   username,
      password:   password,
      rememberMe: rememberMe,
    );

    if (err != null) {
      state = state.copyWith(isLoading: false, error: err);
      return err;
    }

    state = state.copyWith(
      isLoading:  false,
      isLoggedIn: true,
      role:       AuthService.instance.currentRole,
      fullName:   AuthService.instance.currentFullName,
      userId:     AuthService.instance.currentUserId,
    );

    return null;
  }

  /// Logout
  Future<void> logout() async {
    await AuthService.instance.logout();
    state = const AuthState();
  }
}
