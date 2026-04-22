import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class AdminSecurityService {
  static final AdminSecurityService _instance =
      AdminSecurityService._internal();
  factory AdminSecurityService() => _instance;
  AdminSecurityService._internal();

  bool _isAdminAuthorized = false;
  DateTime? _adminLoginTime;
  static const Duration _sessionTimeout = Duration(minutes: 15);

  bool get isAdminAuthorized => _isAdminAuthorized;

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

      // Additional validation - ensure user is properly authenticated
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        AppLogger.warn('Admin access denied: No valid session');
        return false;
      }

      // Use secure Edge Function for passcode validation
      final response = await Supabase.instance.client.functions.invoke(
        'validate-admin-passcode',
        body: {
          'passcode': passcode,
        },
      );

      final data = response.data;

      if (data['success'] == true) {
        _isAdminAuthorized = true;
        _adminLoginTime = DateTime.now();
        AppLogger.info('Admin access granted for user: ${user.id}');
        return true;
      } else {
        AppLogger.warn(
            'Admin access denied: ${data['message'] ?? 'Unknown error'}');
        return false;
      }
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
