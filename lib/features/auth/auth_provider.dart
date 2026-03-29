import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _authSessionKey = 'auth.is_authenticated';
const _authPhoneKey = 'auth.phone_number';
const _pendingPhoneKey = 'auth.pending_phone';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String? phoneNumber;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.phoneNumber,
  });

  AuthState copyWith(
      {bool? isAuthenticated,
      bool? isLoading,
      String? errorMessage,
      String? phoneNumber,
      bool clearError = false}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  Future<bool> signInWithOtp(String phone) async {
    final normalizedPhone = phone.trim();
    if (!_isValidPhone(normalizedPhone)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Enter a valid 10-digit mobile number.",
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPhoneKey, normalizedPhone);
    await Future.delayed(const Duration(milliseconds: 400));

    state = state.copyWith(
      isLoading: false,
      phoneNumber: normalizedPhone,
      clearError: true,
    );
    return true;
  }

  Future<void> checkSession() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    final isAuthenticated = prefs.getBool(_authSessionKey) ?? false;
    final phoneNumber = prefs.getString(_authPhoneKey);
    final phone = prefs.getString(_authPhoneKey);

    state = AuthState(
    state = state.copyWith(
      isAuthenticated: isAuthenticated,
      phoneNumber: phone,
      isLoading: false,
      phoneNumber: phoneNumber,
    );
  }

  Future<void> login(String otp) async {
  Future<bool> verifyPassword(String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final normalizedOtp = otp.trim();
    await Future.delayed(const Duration(milliseconds: 500));

    if (!_isValidOtp(normalizedOtp)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Enter a valid 6-digit OTP.",
      );
      return;
    // Hardcoded testing password logic
    if (password == '123456') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authSessionKey, true);
      if (state.phoneNumber != null) {
        await prefs.setString(_authPhoneKey, state.phoneNumber!);
      }
      state = state.copyWith(isAuthenticated: true, isLoading: false);
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final pendingPhone =
        prefs.getString(_pendingPhoneKey) ?? state.phoneNumber?.trim();

    if (!_isValidPhone(pendingPhone)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "OTP session expired. Please request a new OTP.",
      );
      return;
    }

    await prefs.setBool(_authSessionKey, true);
    await prefs.setString(_authPhoneKey, pendingPhone!);
    await prefs.remove(_pendingPhoneKey);

    state = AuthState(
      isAuthenticated: true,
    state = state.copyWith(
      isLoading: false,
      phoneNumber: pendingPhone,
      errorMessage: "Incorrect password. Try 123456 for testing.",
    );
    return false;
  }

  Future<void> logout() async {
  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authSessionKey);
    await prefs.remove(_authPhoneKey);
    await prefs.remove(_pendingPhoneKey);
    await prefs.clear();
    state = AuthState();
  }

  bool _isValidPhone(String? value) {
    if (value == null) return false;
    return RegExp(r'^\d{10}$').hasMatch(value);
  }

  bool _isValidOtp(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value);
  }
  bool _isValidPhone(String phone) => phone.length == 10;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
