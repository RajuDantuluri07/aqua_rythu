import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0EA5E9); // Example blue
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
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

class AppTypography {
  // Placeholder for typography if needed
}