import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'app_config_service.dart';

class AdminSecurityService {
  static final AdminSecurityService _instance =
      AdminSecurityService._internal();
  factory AdminSecurityService() => _instance;
  AdminSecurityService._internal();

  bool _isAdminAuthorized = false;
  DateTime? _adminLoginTime;
  static const Duration _sessionTimeout = Duration(minutes: 15);

  bool get isAdminAuthorized => _isAdminAuthorized;

  // Temporary admin logic based on email
  bool isAdmin(User? user) {
    if (user == null) return false;

    const adminEmail = "naveendantuluri1@gmail.com";
    final isAdminUser = user.email == adminEmail;

    // Debug logging for verification
    print("ADMIN CHECK: ${user.email} -> $isAdminUser");
    AppLogger.debug("ADMIN CHECK: ${user.email} -> $isAdminUser");

    return isAdminUser;
  }

  Future<bool> validateAdminAccess(String passcode) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Debug log for auth state
      AppLogger.debug(
          'Auth state check - User: ${user?.id ?? "null"}, Email: ${user?.email ?? "null"}');

      if (user == null) {
        AppLogger.warn('Admin access denied: No authenticated user');
        return false;
      }

      // Check if user is admin based on email
      if (!isAdmin(user)) {
        AppLogger.warn('Admin access denied: User not authorized');
        return false;
      }

      // Additional validation - ensure user is properly authenticated
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        AppLogger.warn('Admin access denied: No valid session');
        return false;
      }

      // Get configured admin passcode
      final configService = AppConfigService(Supabase.instance.client);
      final adminConfig = await configService.getAdminSecurityConfig();
      final configuredPasscode = adminConfig['admin_passcode'] as String?;

      // Validate passcode is properly configured
      if (configuredPasscode == null ||
          configuredPasscode.isEmpty ||
          configuredPasscode == 'SET_IN_PRODUCTION') {
        AppLogger.error(
            'Admin access denied: Passcode not configured in production');
        return false;
      }

      // Validate provided passcode against configured passcode
      if (passcode != configuredPasscode) {
        AppLogger.warn('Admin access denied: Invalid passcode');
        return false;
      }

      // Grant access to admin users
      _isAdminAuthorized = true;
      _adminLoginTime = DateTime.now();
      AppLogger.info('Admin access granted for user: ${user.email}');
      return true;
    } catch (e) {
      // Log error but don't expose details
      AppLogger.error('Admin validation error: $e');
      return false;
    }
  }

  void revokeAdminAccess() {
    _isAdminAuthorized = false;
    _adminLoginTime = null;
    AppLogger.info('Admin access revoked');
  }

  Future<bool> checkCurrentAdminStatus() async {
    try {
      // Check session timeout first
      if (_isAdminAuthorized && _adminLoginTime != null) {
        final now = DateTime.now();
        final sessionAge = now.difference(_adminLoginTime!);

        if (sessionAge > _sessionTimeout) {
          AppLogger.info(
              'Admin session expired after ${sessionAge.inMinutes} minutes');
          revokeAdminAccess();
          return false;
        }
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _isAdminAuthorized = false;
        _adminLoginTime = null;
        return false;
      }

      // Admin status is now managed by session only
      // If user has valid session, they remain authorized
      // Re-authentication required when session expires
      return _isAdminAuthorized;
    } catch (e) {
      AppLogger.error('Admin status check error: $e');
      _isAdminAuthorized = false;
      _adminLoginTime = null;
      return false;
    }
  }

  // Check if admin session is still valid
  bool isSessionValid() {
    if (!_isAdminAuthorized || _adminLoginTime == null) {
      return false;
    }

    final now = DateTime.now();
    final sessionAge = now.difference(_adminLoginTime!);
    return sessionAge <= _sessionTimeout;
  }

  // Get remaining session time
  Duration? getRemainingSessionTime() {
    if (!isSessionValid()) {
      return null;
    }

    final now = DateTime.now();
    final remaining = _sessionTimeout - now.difference(_adminLoginTime!);
    return remaining.isNegative ? null : remaining;
  }
}
