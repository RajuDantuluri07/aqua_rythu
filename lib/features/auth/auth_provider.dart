import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({bool? isAuthenticated, bool? isLoading, String? errorMessage, bool clearError = false}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  Future<bool> signInWithOtp(String phone) async {
  // TEMP MOCK LOGIC (Phase 1: UI only)
  await Future.delayed(Duration(seconds: 1));

  // Always succeed for now
  return true;
}

  /// Simulate checking local storage/session on app start
  Future<void> checkSession() async {
    state = state.copyWith(isLoading: true);
    // Simulate network/db delay
    await Future.delayed(const Duration(seconds: 2));
    state = AuthState(isAuthenticated: false, isLoading: false);
  }

  Future<void> login(String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.delayed(const Duration(seconds: 1));

    if (otp == "123456") { // "Correct" OTP for simulation
      state = AuthState(isAuthenticated: true, isLoading: false);
    } else {
      state = state.copyWith(
          isLoading: false, errorMessage: "Invalid OTP. Please try again.");
    }
  }

  void logout() {
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});