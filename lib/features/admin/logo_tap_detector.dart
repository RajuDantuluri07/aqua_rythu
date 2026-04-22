import 'package:flutter/material.dart';
import 'admin_login_widget.dart';

class LogoTapDetector extends StatefulWidget {
  final Widget child;
  
  const LogoTapDetector({
    super.key,
    required this.child,
  });

  @override
  State<LogoTapDetector> createState() => _LogoTapDetectorState();
}

class _LogoTapDetectorState extends State<LogoTapDetector> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _onLogoTap() {
    final now = DateTime.now();

    // Reset counter if more than 2 seconds have passed
    if (_lastTap == null || now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTap = now;

    // Trigger admin login after 5 taps
    if (_tapCount >= 5) {
      _tapCount = 0;
      _lastTap = null;
      
      // Show admin login dialog
      AdminLoginWidget.showAdminLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onLogoTap,
      child: widget.child,
    );
  }
}
