import 'package:flutter/material.dart';

/// Success popup with lightweight animated icon (no external dependencies).
/// Auto-dismisses after 1.5 seconds per UX spec.
///
/// Usage:
/// ```dart
/// showSuccessPopup(
///   context: context,
///   title: 'Feed Logged',
///   message: 'Your feed and tray check have been recorded.',
///   onDismiss: () => Navigator.pop(context),
/// );
/// ```
class SuccessPopup extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onDismiss;
  final double animationSize;

  const SuccessPopup({
    super.key,
    required this.title,
    required this.message,
    this.onDismiss,
    this.animationSize = 120,
  });

  @override
  State<SuccessPopup> createState() => _SuccessPopupState();
}

class _SuccessPopupState extends State<SuccessPopup> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss after 1.5 seconds per UX spec (< 1.5s animation rule)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated success icon (lightweight, no Lottie)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Show a success popup with the checkmark animation.
/// Auto-dismisses within ~1.5 sec, no UI freeze.
Future<T?> showSuccessPopup<T>({
  required BuildContext context,
  required String title,
  required String message,
  VoidCallback? onDismiss,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) => SuccessPopup(
      title: title,
      message: '$title ✅\n$message',
      onDismiss: onDismiss,
    ),
  );
}
