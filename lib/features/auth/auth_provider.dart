import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/user_provider.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../../core/utils/logger.dart';

class AppAuthState {
  final bool isAuthenticated;
  final bool isLoading;
  /// True while the initial session check is in progress (cold start / app resume).
  /// AuthGate should show a splash screen until this is false.
  final bool isCheckingSession;
  final String? errorMessage;
  final String? email;
  const AppAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isCheckingSession = true,
    this.errorMessage,
    this.email,
  });
  AppAuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isCheckingSession,
    String? errorMessage,
    String? email,
    bool clearError = false,
  }) {
    return AppAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isCheckingSession: isCheckingSession ?? this.isCheckingSession,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      email: email ?? this.email,
    );
  }
}

enum _AuthFlow { email, otp }

String _friendlyAuthError(Object e, {_AuthFlow flow = _AuthFlow.email}) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
    return flow == _AuthFlow.otp
        ? 'Wrong phone number or OTP. Please try again.'
        : 'Incorrect email or password. Please try again.';
  }
  if (msg.contains('user already registered') || msg.contains('already been registered')) {
    return flow == _AuthFlow.otp
        ? 'This phone number is already registered. Please log in.'
        : 'This email is already registered. Please log in.';
  }
  if (msg.contains('otp') || msg.contains('token has expired') || msg.contains('otp expired')) {
    return flow == _AuthFlow.otp
        ? 'OTP expired or invalid. Please request a new one.'
        : 'Your confirmation link has expired. Please sign up again.';
  }
  if (msg.contains('email not confirmed') || msg.contains('not confirmed')) {
    return 'Please confirm your email first. Check your inbox for the confirmation link.';
  }
  if (msg.contains('network') || msg.contains('socketexception') || msg.contains('connection') || msg.contains('failed to fetch')) {
    return 'No internet connection. Please check your network and try again.';
  }
  if (msg.contains('too many requests') || msg.contains('rate limit')) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }
  if (msg.contains('phone') || msg.contains('mobile')) {
    return 'Invalid phone number. Please enter a valid 10-digit number.';
  }
  return 'Something went wrong. Please try again.';
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  final SupabaseClient _supabase;
  final Ref ref;
  
  AuthNotifier(this.ref, {SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client,
        super(const AppAuthState()) {
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
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e, flow: _AuthFlow.email));
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
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e, flow: _AuthFlow.email));
      return false;
    }
  }

  Future<void> checkSession() async {
    // isCheckingSession starts true; always clear it when done.
    try {
      final session = _supabase.auth.currentSession;
      final isLoggedIn = session != null;

      if (isLoggedIn) {
        final userId = session.user.id;
        if (userId.isNotEmpty) {
          try {
            await _syncUserRecord(session.user);
            await ref.read(farmProvider.notifier).loadFarms();
            final farmState = ref.read(farmProvider);
            final pondIds = farmState.farms
                .expand((f) => f.ponds)
                .map((p) => p.id)
                .toList();
            await ref.read(feedHistoryProvider.notifier).loadHistoryForPonds(pondIds);
          } catch (e) {
            AppLogger.error('Session sync failed', e);
          }
        }
      }

      state = state.copyWith(
        isAuthenticated: isLoggedIn,
        isCheckingSession: false,
        email: session?.user.email,
      );
    } catch (e) {
      AppLogger.error('checkSession failed', e);
      state = state.copyWith(isAuthenticated: false, isCheckingSession: false);
    }
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
          'email': user.email ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
        AppLogger.info('User record synced');
      } else {
        // Update email if it changed (guard: email column may not exist yet)
        try {
          await _supabase.from('profiles').update({
            'email': user.email ?? '',
          }).eq('id', user.id);
        } catch (e) {
          AppLogger.error('Profile email update skipped (column may be missing)', e);
        }
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
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e, flow: _AuthFlow.email));
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = const AppAuthState();
  }

  Future<void> signInWithOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase.auth.signInWithOtp(phone: phone);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e, flow: _AuthFlow.otp));
    }
  }

  Future<void> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );
      if (res.user != null) {
        await _syncUserRecord(res.user!);
        state = state.copyWith(isLoading: false, isAuthenticated: true);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Verification failed. Please try again.');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e, flow: _AuthFlow.otp));
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>(
  (ref) => AuthNotifier(ref),
);