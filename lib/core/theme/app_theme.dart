import 'package:flutter/material.dart';

class AppColors {
  // Primary palette (Farm green)
  static const Color primary = Color(0xFF0B8F5A);
  static const Color secondary = Color(0xFF1FAF73);

  // Backgrounds
  static const Color background = Color(0xFFF7F9F8);
  static const Color card = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);

  // Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);

  // Structural
  static const Color border = Color(0xFFE5E7EB);

  // Deprecated (keeping for backwards compatibility during transition)
  @Deprecated('Use cardBg instead of card')
  static const Color cardBg = Color(0xFFFFFFFF);
  @Deprecated('Use danger instead of error')
  static const Color error = Color(0xFFE53935);
  @Deprecated('Use textTertiary instead')
  static const Color textTertiary = Color(0xFF6B7280);
}

class AppRadius {
  // ✅ Defined as BorderRadius to match UI usage
  static final BorderRadius rBase = BorderRadius.circular(12);
  static final BorderRadius rs = BorderRadius.circular(8);
  static final BorderRadius rm = BorderRadius.circular(16);
  static final BorderRadius rl = BorderRadius.circular(24);
}

class AppSpacing {
  // ✅ Defined as double to fix SizedBox multiplication errors
  static const double base = 16;
  static const double s = 8;
  static const double m = 12;
  static const double l = 24;
  static const double xl = 32;

  // Horizontal spacing
  static const SizedBox wS = SizedBox(width: 8);
  static const SizedBox wM = SizedBox(width: 12);
  static const SizedBox wBase = SizedBox(width: 16);

  // Vertical spacing helpers (widgets)
  static const SizedBox hS = SizedBox(height: 8);
  static const SizedBox hM = SizedBox(height: 12);
  static const SizedBox hBase = SizedBox(height: 16);
  static const SizedBox hXl = SizedBox(height: 32);

  // Raw doubles for custom SizedBox
  static const double hXxl = 48.0;
}

class AppTextStyles {
  // ─── Core Type Scale ──────────────────────────────────────────────────────

  // H1: Page/Screen Heading
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontFamily: 'Inter',
  );

  // H2: Section Heading
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFamily: 'Inter',
  );

  // Primary Value: Large numbers/metrics that dominate
  static const TextStyle primaryValue = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    fontFamily: 'Inter',
  );

  // Secondary Value: Important but not dominant
  static const TextStyle secondaryValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: 'Inter',
  );

  // Section Title: Uppercase labels with letter spacing
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: 'Inter',
    letterSpacing: 0.08,
  );

  // Body: Standard text
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: 'Inter',
  );

  // Secondary Text: De-emphasized content
  static const TextStyle secondaryText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'Inter',
  );

  // Meta Info: Small muted text
  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: 'Inter',
  );

  // Button: CTA text
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: 'Inter',
  );

  // Small Label: Uppercase meta labels
  static const TextStyle smallLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontFamily: 'Inter',
    letterSpacing: 0.05,
  );

  // Badge: Small badge text
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: 'Inter',
  );

  // ─── Legacy Aliases (for backwards compatibility) ──────────────────────────

  static const TextStyle heading = h1;

  static const TextStyle subheading = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontFamily: 'Inter',
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w300,
    fontFamily: 'Inter',
  );
}

class AppTypography {
  // Placeholder for typography if needed
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Inter',
      );
}
