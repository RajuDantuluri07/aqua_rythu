import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double base = 16.0;
  static const double l = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  static const SizedBox hXs = SizedBox(height: xs);
  static const SizedBox hS = SizedBox(height: s);
  static const SizedBox hM = SizedBox(height: m);
  static const SizedBox hBase = SizedBox(height: base);
  static const SizedBox hL = SizedBox(height: l);
  static const SizedBox hXl = SizedBox(height: xl);
  static const SizedBox hXxl = SizedBox(height: xxl);

  static const SizedBox wXs = SizedBox(width: xs);
  static const SizedBox wS = SizedBox(width: s);
  static const SizedBox wM = SizedBox(width: m);
  static const SizedBox wBase = SizedBox(width: base);
  static const SizedBox wL = SizedBox(width: l);
}

class AppRadius {
  static const double s = 8.0;
  static const double m = 12.0;
  static const double base = 16.0;
  static const double l = 20.0;
  static const double xl = 24.0;

  static final BorderRadius rs = BorderRadius.circular(s);
  static final BorderRadius rm = BorderRadius.circular(m);
  static final BorderRadius rBase = BorderRadius.circular(base);
  static final BorderRadius rl = BorderRadius.circular(l);
  static final BorderRadius rxl = BorderRadius.circular(xl);
}

class AppColors {
  static const Color primary = Color(0xFF0EA5E9); // Modern Blue
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
}
