import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Debug dashboard screen for feed engine diagnostics.
///
/// ⚠️ ONLY AVAILABLE IN DEBUG BUILDS
/// This screen is stripped from release builds via kDebugMode check.
///
/// To access: 5-tap on pond name in dashboard
class DebugDashboardScreen extends StatelessWidget {
  final String pondId;

  const DebugDashboardScreen({
    super.key,
    required this.pondId,
  });

  @override
  Widget build(BuildContext context) {
    // Safety guard - should never show in release
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text('Debug mode only'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Dashboard'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Debug Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pond ID: $pondId',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Engine diagnostics and debug tools\nwould be shown here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
