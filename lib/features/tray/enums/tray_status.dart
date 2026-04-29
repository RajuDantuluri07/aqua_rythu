import 'package:flutter/material.dart';

/// Unified tray status enum used across UI, engine, and database.
///
/// This is the single source of truth for tray states.
/// All tray-related logic must use this enum.
enum TrayStatus {
  empty,
  light,
  medium,
  heavy,
}

const trayStatusInputValues = <TrayStatus>[
  TrayStatus.empty,
  TrayStatus.light,
  TrayStatus.medium,
  TrayStatus.heavy,
];

extension TrayStatusUI on TrayStatus {
  String get name {
    switch (this) {
      case TrayStatus.empty:
        return 'empty';
      case TrayStatus.light:
        return 'light';
      case TrayStatus.medium:
        return 'medium';
      case TrayStatus.heavy:
        return 'heavy';
    }
  }

  /// Display label shown in UI
  String get label {
    switch (this) {
      case TrayStatus.empty:
        return 'Empty';
      case TrayStatus.light:
        return 'Slight Left';
      case TrayStatus.medium:
        return 'More Left';
      case TrayStatus.heavy:
        return 'Too Much Left';
    }
  }

  /// Subtext description shown in UI
  String get description {
    switch (this) {
      case TrayStatus.empty:
        return 'No feed left';
      case TrayStatus.light:
        return 'Small amount remaining';
      case TrayStatus.medium:
        return 'Noticeable feed remaining';
      case TrayStatus.heavy:
        return 'Excess feed remaining';
    }
  }

  /// Action hint shown after selection
  String get hint {
    switch (this) {
      case TrayStatus.empty:
        return 'Increase feed tomorrow';
      case TrayStatus.light:
        return 'Feeding is correct';
      case TrayStatus.medium:
        return 'Reduce feed slightly';
      case TrayStatus.heavy:
        return 'Reduce feed immediately';
    }
  }

  /// Primary color for UI elements
  Color get color {
    switch (this) {
      case TrayStatus.empty:
        return const Color(0xFF4CAF50); // Green
      case TrayStatus.light:
        return const Color(0xFF2196F3); // Blue
      case TrayStatus.medium:
        return const Color(0xFFFF9800); // Amber
      case TrayStatus.heavy:
        return const Color(0xFFF44336); // Red
    }
  }

  /// Light tint color for backgrounds
  Color get lightColor {
    switch (this) {
      case TrayStatus.empty:
        return const Color(0xFFE8F5E9);
      case TrayStatus.light:
        return const Color(0xFFE3F2FD);
      case TrayStatus.medium:
        return const Color(0xFFFFF3E0);
      case TrayStatus.heavy:
        return const Color(0xFFFFEBEE);
    }
  }

  IconData get icon {
    switch (this) {
      case TrayStatus.empty:
        return Icons.check_circle_outline;
      case TrayStatus.light:
        return Icons.check_circle;
      case TrayStatus.medium:
        return Icons.warning;
      case TrayStatus.heavy:
        return Icons.error;
    }
  }
}

TrayStatus trayStatusFromName(String value) {
  switch (value.toLowerCase()) {
    case 'empty':
    case 'completed':
      return TrayStatus.empty;
    case 'light':
    case 'slight':
    case 'partial':
      return TrayStatus.light;
    case 'medium':
    case 'more':
      return TrayStatus.medium;
    case 'heavy':
    case 'too much':
    case 'full':
      return TrayStatus.heavy;
    default:
      return TrayStatus.light; // Safe fallback
  }
}

/// Migration mapping from old enum values to new unified enum.
///
/// Old values:
/// - 'completed' → 'empty' (feed was fully consumed)
/// - 'partial' → 'light' (small amount remaining)
/// - 'full' → 'heavy' (excess feed remaining)
TrayStatus migrateOldTrayStatus(String oldValue) {
  switch (oldValue.toLowerCase()) {
    case 'completed':
      return TrayStatus.empty;
    case 'partial':
      return TrayStatus.light;
    case 'full':
      return TrayStatus.heavy;
    default:
      return TrayStatus.light; // Safe fallback
  }
}
