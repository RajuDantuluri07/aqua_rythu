import 'package:flutter/material.dart';

/// Shown when a Supabase RLS policy blocks the current user's request.
/// Used in place of a generic error screen so farmers see a clear message
/// rather than a confusing network error.
class AccessDeniedView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AccessDeniedView({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 56, color: Color(0xFF9E9E9E)),
            const SizedBox(height: 20),
            const Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ??
                  'You do not have permission to view this content.\n'
                  'Contact your farm owner if this is unexpected.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
