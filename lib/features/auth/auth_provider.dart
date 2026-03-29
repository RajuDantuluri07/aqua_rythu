import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String? phoneNumber;
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.phoneNumber,
  });
  AuthState copyWith({bool? isAuthenticated, bool? isLoading,
      String? errorMessage, String? phoneNumber, bool clearError = false}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _supabase = Supabase.instance.client;
  AuthNotifier() : super(const AuthState()) {
    checkSession();
  }

  Future<bool> signInWithOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase.auth.signInWithOtp(phone: '+91$phone');
      state = state.copyWith(isLoading: false, phoneNumber: phone);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _supabase.auth.verifyOTP(
        phone: '+91$phone',
        token: otp.trim(),
        type: OtpType.sms,
      );
      final ok = res.session != null;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: ok,
        phoneNumber: res.user?.phone ?? phone,
        errorMessage: ok ? null : 'Invalid OTP. Try again.',
      );
      return ok;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'OTP verification failed.');
      return false;
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign In failed. Please try again.',
      );
    }
  }

  Future<void> checkSession() async {
    final session = _supabase.auth.currentSession;
    state = state.copyWith(
      isAuthenticated: session != null,
      phoneNumber: session?.user.phone,
    );
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);