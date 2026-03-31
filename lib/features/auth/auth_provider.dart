import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/user_provider.dart';

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
  final Ref ref;
  
  AuthNotifier(this.ref) : super(const AuthState()) {
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
      final user = res.user;
final ok = user != null;
      
      if (ok) {
        final user = res.user;

if (user == null) {
  state = state.copyWith(
    isLoading: false,
    errorMessage: 'User not found after OTP',
  );
  return false;
}

final userId = user.id;
final userPhone = user.phone ?? phone;
        
        // ✅ Check if user already exists in users table
        final existing = await _supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
        
        // ✅ If not exist, create new user record
        if (existing == null) {
          try {
            await _supabase.from('users').insert({
              'id': userId,
              'phone': userPhone,
              'name': 'User $phone',
              'email': '',
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            print('⚠️ Warning: Failed to create user record: $e');
            // Continue anyway - user auth succeeded
          }
        }
        
        // ✅ Update userProvider with userId
        ref.read(userProvider.notifier).setUserId(userId);
      }
      
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
    final isLoggedIn = session != null;
    
    if (isLoggedIn) {
      final userId = session?.user.id ?? '';
      
      // ✅ Sync existing user on session restore
      if (userId.isNotEmpty) {
        try {
          // Check if user exists
          final existing = await _supabase
            .from('users')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
          
          // Create if doesn't exist
          if (existing == null) {
            await _supabase.from('users').insert({
              'id': userId,
              'phone': session?.user.phone ?? '',
              'name': 'User',
              'email': session?.user.email ?? '',
              'created_at': DateTime.now().toIso8601String(),
            }).onError((error, stackTrace) {
              print('⚠️ Warning: Could not create user record: $error');
            });
          }
          
          // Update userProvider
          ref.read(userProvider.notifier).setUserId(userId);
        } catch (e) {
          print('⚠️ Warning: Session sync failed: $e');
        }
      }
    }
    
    state = state.copyWith(
      isAuthenticated: isLoggedIn,
      phoneNumber: session?.user.phone,
    );
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);