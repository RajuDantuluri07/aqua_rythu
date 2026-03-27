import 'package:flutter/material.dart';

import '../features/auth/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/farm/add_farm_screen.dart';
import '../features/pond/add_pond_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/pond/pond_dashboard_screen.dart';
import '../features/pond/edit_pond_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';
  static const profile = '/profile';
  static const addFarm = '/add-farm';
  static const addPond = '/add-pond';
  static const editPond = '/edit-pond';
  static const dashboard = '/dashboard';
  static const pondDashboard = '/pond-dashboard';

  static Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    otp: (context) => const OtpScreen(),
    profile: (context) => const ProfileScreen(),
    addFarm: (context) => const AddFarmScreen(),
    addPond: (context) => const AddPondScreen(),
    editPond: (context) => const EditPondScreen(), 
    dashboard: (context) => const DashboardScreen(),
    pondDashboard: (context) => const PondDashboardScreen(),
  };
}