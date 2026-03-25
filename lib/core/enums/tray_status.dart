import 'package:flutter/material.dart';

enum TrayStatus {
  full,
  partial,
  empty,
}

extension TrayStatusUI on TrayStatus {
  String get label {
    switch (this) {
      case TrayStatus.full:
        return 'Full';
      case TrayStatus.partial:
        return 'Partial';
      case TrayStatus.empty:
        return 'Empty';
    }
  }

  String get description {
    switch (this) {
      case TrayStatus.full:
        return '-8% — overfeeding, reduce';
      case TrayStatus.partial:
        return '0% — no change';
      case TrayStatus.empty:
        return '+8% — all feed eaten, increase';
    }
  }

  Color get color {
    switch (this) {
      case TrayStatus.full:
        return Colors.red;
      case TrayStatus.partial:
        return Colors.orange;
      case TrayStatus.empty:
        return Colors.green;
    }
  }

  IconData get icon {
    switch (this) {
      case TrayStatus.full:
        return Icons.circle;
      case TrayStatus.partial:
        return Icons.change_history;
      case TrayStatus.empty:
        return Icons.check_circle_outline;
    }
  }
}