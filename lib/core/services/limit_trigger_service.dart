import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqua_rythu/core/utils/logger.dart';

enum LimitType { farm, pond, role }

class LimitTriggerService {
  static const String _dismissalCountPrefix = 'limit_dismissal_count_';
  static const String _lastShownPrefix = 'limit_last_shown_';
  
  static const int _maxFreeFarms = 1;
  static const int _maxFreePonds = 3;
  static const int _maxDismissalsBeforeBlock = 2;
  static const Duration _reentryCooldown = Duration(hours: 24);

  /// Check if user has hit the farm limit
  static bool hasHitFarmLimit(int currentFarmCount) {
    return currentFarmCount >= _maxFreeFarms;
  }

  /// Check if user has hit the pond limit
  static bool hasHitPondLimit(int currentPondCount) {
    return currentPondCount >= _maxFreePonds;
  }

  /// Check if trigger should be shown based on re-entry logic
  static Future<bool> shouldShowTrigger(LimitType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type.toString().split('.').last;
    
    final dismissalCount = prefs.getInt('$_dismissalCountPrefix$key') ?? 0;
    final lastShownTimestamp = prefs.getInt('$_lastShownPrefix$key');
    
    // Block if dismissed too many times
    if (dismissalCount >= _maxDismissalsBeforeBlock) {
      AppLogger.info('Limit trigger blocked: dismissed $dismissalCount times');
      return false;
    }
    
    // Check cooldown period
    if (lastShownTimestamp != null) {
      final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownTimestamp);
      final timeSinceLastShown = DateTime.now().difference(lastShown);
      
      if (timeSinceLastShown < _reentryCooldown) {
        AppLogger.info('Limit trigger blocked: cooldown not met');
        return false;
      }
    }
    
    return true;
  }

  /// Record that a trigger was shown
  static Future<void> recordTriggerShown(LimitType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type.toString().split('.').last;
    
    await prefs.setInt('$_lastShownPrefix$key', DateTime.now().millisecondsSinceEpoch);
    AppLogger.info('Limit trigger shown: $type');
  }

  /// Record that a trigger was dismissed
  static Future<void> recordTriggerDismissed(LimitType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type.toString().split('.').last;
    
    final currentCount = prefs.getInt('$_dismissalCountPrefix$key') ?? 0;
    await prefs.setInt('$_dismissalCountPrefix$key', currentCount + 1);
    AppLogger.info('Limit trigger dismissed: $type (count: ${currentCount + 1})');
  }

  /// Reset dismissal count (for testing or after upgrade)
  static Future<void> resetDismissalCount(LimitType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type.toString().split('.').last;
    
    await prefs.remove('$_dismissalCountPrefix$key');
    await prefs.remove('$_lastShownPrefix$key');
    AppLogger.info('Limit trigger reset: $type');
  }

  /// Log limit hit event for analytics
  static void logLimitHit({
    required LimitType type,
    required int currentUsage,
    required String plan,
  }) {
    AppLogger.info('Limit hit event: ${{
      "event": "limit_hit",
      "type": type.toString().split('.').last,
      "current_usage": currentUsage,
      "plan": plan,
    }}');
    
    // TODO: Send to analytics service
  }

  /// Log upgrade click from trigger
  static void logUpgradeClick({required LimitType type}) {
    AppLogger.info('Upgrade click from trigger: ${{
      "event": "upgrade_click",
      "trigger_type": type.toString().split('.').last,
    }}');
    
    // TODO: Send to analytics service
  }
}
