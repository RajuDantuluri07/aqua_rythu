import 'models/feed_input.dart';

class AdjustmentEngine {
  static double calculate(FeedInput input) {
    double factor = 1.0;

    // Feeding response
    if (input.feedingScore >= 4) factor += 0.05;
    if (input.feedingScore == 3) factor -= 0.10;
    if (input.feedingScore <= 2) factor -= 0.25;

    // Intake %
    if (input.intakePercent > 95) {
      factor += 0.05;
    } else if (input.intakePercent < 85) {
      factor -= 0.10;
    }
    if (input.intakePercent < 70) {
      factor -= 0.25;
    }

    // 🚨 Water rules - CRITICAL STOP
    if (input.dissolvedOxygen < 4) return 0.0;
    if (input.dissolvedOxygen < 5) factor -= 0.30;

    if (input.temperature > 32) factor -= 0.10;
    if (input.phChange > 0.5) factor -= 0.10;
    if (input.ammonia > 0.1) factor -= 0.20;

    // ✅ IMPROVED: Mortality is now proportional, not binary
    // Receives daily mortality count, not boolean
    if (input.mortality > 0 && input.seedCount > 0) {
      final mortalityPercent = input.mortality / input.seedCount;
      
      if (mortalityPercent >= 0.05) {
        // 5%+ mortality per day: significant concern → -20%
        factor -= 0.20;
      } else if (mortalityPercent >= 0.02) {
        // 2-5% mortality per day: concerning → -10%
        factor -= 0.10;
      } else if (mortalityPercent > 0) {
        // < 2% mortality per day: minor issue → -5%
        factor -= 0.05;
      }
    }

    return _clamp(factor);
  }

  static double _clamp(double value) {
    if (value < 0.5) return 0.5;
    if (value > 1.2) return 1.2;
    return value;
  }
}