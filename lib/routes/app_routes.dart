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
    inventorySetup: (context) => const InventorySetupScreen(),
    inventoryDashboard: (context) => const InventoryDashboardScreen(),
    expenseSummary: (context) {
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
