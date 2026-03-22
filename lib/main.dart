import 'package:flutter/material.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/farm/add_farm_screen.dart';
import 'features/pond/add_pond_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/pond/pond_dashboard_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/profile/profile_screen.dart';
import 'theme/app_theme.dart';

import 'package:flutter/foundation.dart'; // 👈 IMPORTANT
import 'package:aqua_rythu/core/engines/feed_state_engine.dart';

void testEngine() {
  final state = FeedStateEngine.getRoundState(
    doc: 35,
    round: 2,
    totalRounds: 4,
    feedDone: {1: true},
    trayDone: {},
  );

  debugPrint("------ ENGINE TEST ------");
  debugPrint("isDone: ${state.isDone}");
  debugPrint("isCurrent: ${state.isCurrent}");
  debugPrint("isLocked: ${state.isLocked}");
  debugPrint("showMarkFeed: ${state.showMarkFeed}");
  debugPrint("showTrayCTA: ${state.showTrayCTA}");
  debugPrint("-------------------------");
}
void main() {
  testEngine(); // 👈 TEMP TEST

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aqua Rythu',

      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.dashboard,

      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.otp: (context) => const OtpScreen(),
        AppRoutes.addFarm: (context) => const AddFarmScreen(),
        AppRoutes.addPond: (context) => const AddPondScreen(),
        AppRoutes.dashboard: (context) => const DashboardScreen(),
        AppRoutes.pondDashboard: (context) => const PondDashboardScreen(),
        AppRoutes.profile: (context) => const ProfileScreen(),
      },
    );
  }
}
