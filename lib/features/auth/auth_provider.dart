import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/user_provider.dart';
import '../farm/farm_provider.dart';
import '../../core/utils/logger.dart';

class AppAuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String? email;
  const AppAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.email,
  });
  AppAuthState copyWith({bool? isAuthenticated, bool? isLoading,
      String? errorMessage, String? email, bool clearError = false}) {
    return AppAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      email: email ?? this.email,
    );
  }
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  final _supabase = Supabase.instance.client;
  final Ref ref;
  
  AuthNotifier(this.ref) : super(const AppAuthState()) {
    checkSession();
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await _syncUserRecord(res.user!);
        state = state.copyWith(isLoading: false, isAuthenticated: true, email: email);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await _syncUserRecord(res.user!);
        // If Supabase auto-confirms, session will be present. 
        // If confirmation is required, session will be null.
        final isLoggedIn = res.session != null;
        state = state.copyWith(isLoading: false, isAuthenticated: isLoggedIn, email: email);
        return isLoggedIn;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
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
          await _syncUserRecord(session!.user);

          // ✅ Sync farms for returning users
          await ref.read(farmProvider.notifier).loadFarms();
        } catch (e) {
          AppLogger.error('Session sync failed', e);
        }
      }
    }
    
    state = state.copyWith(
      isAuthenticated: isLoggedIn,
      email: session?.user.email,
    );
  }

  Future<void> _syncUserRecord(User user) async {
    try {
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('profiles').insert({
          'id': user.id,
          'name': '',
          'phone': '',
          'created_at': DateTime.now().toIso8601String(),
        });
        AppLogger.info('User record synced');
      }

      // Update userProvider
      ref.read(userProvider.notifier).setUserId(user.id);
      ref.read(userProvider.notifier).updateProfile(email: user.email);
    } catch (e) {
      AppLogger.error('User record sync failed', e);
    }
  }

  Future<bool> resetPasswordForEmail(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutter://reset-password', // Optional: Deep link for password reset
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = const AppAuthState();
  }

  // OTP flow stubs — not used in current email/password MVP
  Future<void> signInWithOtp(String phone) async {
    state = state.copyWith(errorMessage: 'OTP login not supported yet');
  }

  Future<void> verifyOtp(String phone, String otp) async {
    state = state.copyWith(errorMessage: 'OTP verification not supported yet');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>(
  (ref) => AuthNotifier(ref),
);