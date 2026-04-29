import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/farm/add_farm_screen.dart';
import '../features/pond/add_pond_screen.dart';
import '../features/pond/edit_pond_screen.dart';
import '../features/dashboard/dashboard_screen_fixed.dart';
import '../features/pond/pond_dashboard_screen.dart';
import '../features/feed/feed_schedule_screen.dart';
import '../features/home/home_screen.dart';
import '../features/inventory/inventory_setup_screen.dart';
import '../features/inventory/inventory_dashboard_screen.dart';
import '../features/expense/expense_summary_screen.dart';
import '../features/expense/add_expense_screen.dart';
import '../core/config/feature_flags.dart';
// Admin module removed temporarily
// import '../features/admin/admin_passcode_screen.dart';
// import '../features/admin/admin_dashboard_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const profile = '/profile';
  static const addFarm = '/add-farm';
  static const addPond = '/add-pond';
  static const editPond = '/edit-pond';
  static const dashboard = '/dashboard';
  static const pondDashboard = '/pond-dashboard';
  static const feedSchedule = '/feed-schedule';
  static const home = '/home';
  static const inventorySetup = '/inventory_setup';
  static const inventoryDashboard = '/inventory_dashboard';
  static const expenseSummary = '/expense-summary';
  static const addExpense = '/add-expense';
  static const adminPasscode = '/admin/passcode';
  static const adminDashboard = '/admin/dashboard';

  static Map<String, Widget Function(BuildContext)> routes = {
    login: (context) => const LoginScreen(),
    profile: (context) => const ProfileScreen(),
    addFarm: (context) => const AddFarmScreen(),
    addPond: (context) => const AddPondScreen(),
    editPond: (context) {
      final pondId = ModalRoute.of(context)?.settings.arguments as String?;
      if (pondId == null || pondId.isEmpty) return const PondDashboardScreen();
      return EditPondScreen(pondId: pondId);
    },
    dashboard: (context) => const DashboardScreen(),
    pondDashboard: (context) => const PondDashboardScreen(),
    feedSchedule: (context) {
      final pondId = ModalRoute.of(context)?.settings.arguments as String?;
      if (pondId == null || pondId.isEmpty) return const PondDashboardScreen();
      return FeedScheduleScreen(pondId: pondId);
    },
    home: (context) => const HomeScreen(),
    inventorySetup: (context) => FeatureFlags.isInventoryVisible
        ? const InventorySetupScreen()
        : const _FeatureDisabledScreen(featureName: 'Inventory'),
    inventoryDashboard: (context) => FeatureFlags.isInventoryVisible
        ? const InventoryDashboardScreen()
        : const _FeatureDisabledScreen(featureName: 'Inventory'),
    expenseSummary: (context) {
      if (!FeatureFlags.isExpenseVisible) {
        return const _FeatureDisabledScreen(featureName: 'Expense');
      }
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
      if (args == null || args['cropId'] == null || args['farmId'] == null) {
        return const Scaffold(
          body: Center(
            child: Text('Invalid arguments: cropId and farmId required'),
          ),
        );
      }
      return ExpenseSummaryScreen(
        cropId: args['cropId']!,
        farmId: args['farmId']!,
      );
    },
    addExpense: (context) {
      if (!FeatureFlags.isExpenseVisible) {
        return const _FeatureDisabledScreen(featureName: 'Expense');
      }
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
      if (args == null || args['cropId'] == null || args['farmId'] == null) {
        return const Scaffold(
          body: Center(
            child: Text('Invalid arguments: cropId and farmId required'),
          ),
        );
      }
      return AddExpenseScreen(
        cropId: args['cropId']!,
        farmId: args['farmId']!,
      );
    },
    // Admin routes removed temporarily
    // adminPasscode: (context) => const AdminPasscodeScreen(),
    // adminDashboard: (context) => const AdminDashboardScreen(),
  };
}

/// Screen shown when a feature is disabled via feature flags.
class _FeatureDisabledScreen extends StatelessWidget {
  final String featureName;

  const _FeatureDisabledScreen({required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(featureName),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$featureName Coming Soon',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This feature is currently disabled for the launch. We\'re working hard to bring it to you soon.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
