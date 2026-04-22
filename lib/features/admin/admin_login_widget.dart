import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/admin_security_service.dart';
import '../../core/utils/logger.dart';
import '../../routes/app_routes.dart';

class AdminLoginWidget {
  static void showAdminLogin(BuildContext context) {
    // Check auth state before showing admin login
    final user = Supabase.instance.client.auth.currentUser;
    final session = Supabase.instance.client.auth.currentSession;

    AppLogger.debug(
        'Admin login attempt - User: ${user?.id ?? "null"}, Session: ${session != null ? "valid" : "null"}');

    if (user == null || session == null) {
      AppLogger.warn('Admin login blocked: No authenticated user');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to access admin features'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Admin Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter admin passcode to continue',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: '4-digit passcode',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = controller.text.trim();

              if (input.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a passcode'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Show loading indicator
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Validating...'),
                    ],
                  ),
                ),
              );

              final isValid =
                  await AdminSecurityService().validateAdminAccess(input);

              // Close loading dialog
              Navigator.pop(context);

              if (isValid) {
                Navigator.pushNamed(context, AppRoutes.admin);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid passcode or unauthorized user'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enter'),
          ),
        ],
      ),
    );
  }
}
