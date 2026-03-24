import 'package:flutter/material.dart';

enum TrayStatus {
  empty,
  smallLeft,
  halfLeft,
  fullLeft,
}

extension TrayStatusUI on TrayStatus {
  String get label {
    switch (this) {
      case TrayStatus.empty:
        return 'Empty';
      case TrayStatus.smallLeft:
        return 'Small';
      case TrayStatus.halfLeft:
        return 'Half';
      case TrayStatus.fullLeft:
        return 'Full';
    }
  }

  String get description {
    switch (this) {
      case TrayStatus.empty:
        return '+8% — all feed eaten, increase';
      case TrayStatus.smallLeft:
        return '+3% — normal, slight increase';
      case TrayStatus.halfLeft:
        return '0% — no change';
      case TrayStatus.fullLeft:
        return '-8% — overfeeding, reduce';
    }
  }

  Color get color {
    switch (this) {
      case TrayStatus.empty:
        return Colors.green;
      case TrayStatus.smallLeft:
        return Colors.amber;
      case TrayStatus.halfLeft:
        return Colors.orange;
      case TrayStatus.fullLeft:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case TrayStatus.empty:
        return Icons.check_circle_outline;
      case TrayStatus.smallLeft:
        return Icons.timelapse;
      case TrayStatus.halfLeft:
        return Icons.remove_circle_outline;
      case TrayStatus.fullLeft:
        return Icons.cancel_outlined;
    }
  }
}