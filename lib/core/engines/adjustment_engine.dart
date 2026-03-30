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

    // 🚨 Water rules
    if (input.dissolvedOxygen < 4) return 0.0;
    if (input.dissolvedOxygen < 5) factor -= 0.30;

    if (input.temperature > 32) factor -= 0.10;
    if (input.phChange > 0.5) factor -= 0.10;
    if (input.ammonia > 0.1) factor -= 0.20;

    // Mortality
    if (input.mortality > 0) factor -= 0.20;

    return _clamp(factor);
  }

  static double _clamp(double value) {
    if (value < 0.5) return 0.5;
    if (value > 1.2) return 1.2;
    return value;
  }
}