import 'package:flutter/material.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/profile/farm_settings_provider.dart';
import 'features/profile/user_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/pond/pond_dashboard_screen.dart';
import 'features/auth/auth_provider.dart';
import 'core/config/app_config.dart';
import 'core/language/language_provider.dart';
import 'core/language/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error handler for debugging crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  // Initialize SharedPreferences for settings and profile persistence
  try {
    final prefs = await SharedPreferences.getInstance();
    initializeFarmSettings(prefs);
    initializeUserProvider(prefs);
  } catch (e) {
    debugPrint('SharedPreferences initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aqua Rythu',
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('te'),
      ],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
      routes: AppRoutes.routes,
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Show splash until the initial session check completes.
    // This prevents the login screen from flickering on cold start
    // when a valid session already exists.
    if (authState.isCheckingSession) {
      return const SplashScreen();
    }

    if (authState.isAuthenticated) {
      return const PondDashboardScreen();
    }

    return const LoginScreen();
  }
}