import 'package:flutter/material.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/profile/farm_settings_provider.dart';
import 'features/profile/user_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'features/auth/auth_provider.dart';
import 'features/upgrade/subscription_provider.dart';
import 'core/config/app_config.dart';
import 'core/config/runtime_validator.dart';
import 'core/language/language_provider.dart';
import 'core/language/app_localizations.dart';
import 'core/services/feed_sync_queue.dart';
import 'core/services/feed_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast if required env vars are missing — before touching any network.
  final configErrors = RuntimeValidator.validate();
  if (configErrors.isNotEmpty) {
    runApp(FatalConfigErrorScreen(errors: configErrors));
    return;
  }

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

  // Phase 3+6: Replay any feed operations that failed to sync before the last
  // app exit (offline, crash, network drop). Runs in the background — does not
  // block app startup. The same operation_id guarantees DB-level deduplication.
  FeedSyncQueue().processQueue(FeedService()).catchError((e) {
    debugPrint('FeedSyncQueue startup replay failed: $e');
  });

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

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  DateTime? _lastHydration;
  DateTime? _lastQueueProcess;
  bool _hasSeenOnboarding = false;
  bool _onboardingChecked = false;
  bool _showFeedSyncWarning = false;
  bool _feedSyncWarningDismissed = false;
  static const _kFeedSyncDismissedKey = 'feed_sync_warning_dismissed';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboarding();
    _checkFeedSyncWarning();
  }

  Future<void> _checkFeedSyncWarning() async {
    final prefs = await SharedPreferences.getInstance();
    _feedSyncWarningDismissed = prefs.getBool(_kFeedSyncDismissedKey) ?? false;
    if (_feedSyncWarningDismissed) return;
    final hasFailed = await FeedSyncQueue().hasPermanentlyFailedOps();
    if (mounted && hasFailed) {
      setState(() => _showFeedSyncWarning = true);
    }
  }

  Future<void> _dismissFeedSyncWarning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFeedSyncDismissedKey, true);
    if (mounted) setState(() => _showFeedSyncWarning = false);
  }

  Future<void> _retryFeedSync() async {
    try {
      await FeedSyncQueue().processQueue(FeedService());
      final stillFailing = await FeedSyncQueue().hasPermanentlyFailedOps();
      if (mounted) setState(() => _showFeedSyncWarning = stillFailing);
      if (!stillFailing) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kFeedSyncDismissedKey);
      }
    } catch (e) {
      debugPrint('Feed sync retry failed: $e');
    }
  }

  Future<void> _checkOnboarding() async {
    try {
      final seen = await hasSeenOnboarding();
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = seen;
          _onboardingChecked = true;
        });
      }
    } catch (e) {
      debugPrint('Onboarding check failed: $e');
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = false; // Show onboarding on error — safer for new users
          _onboardingChecked = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-sync subscription and replay pending feed ops on every app resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    if (!ref.read(authProvider).isAuthenticated) return;
    final now = DateTime.now();

    // Subscription hydration — 60 s debounce.
    if (_lastHydration == null ||
        now.difference(_lastHydration!).inSeconds > 60) {
      _lastHydration = now;
      ref.read(subscriptionProvider.notifier).hydrateFromBackend();
    }

    // Feed sync queue — replay on reconnect, 30 s debounce.
    if (_lastQueueProcess == null ||
        now.difference(_lastQueueProcess!).inSeconds > 30) {
      _lastQueueProcess = now;
      FeedSyncQueue().processQueue(FeedService()).then((_) {
        _checkFeedSyncWarning();
      }).catchError((e) {
        debugPrint('FeedSyncQueue resume replay failed: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Hydrate subscription once when the user becomes authenticated.
    ref.listen<AppAuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        ref.read(subscriptionProvider.notifier).hydrateFromBackend();
      }
    });

    // Show splash until both the session check and onboarding flag are ready.
    if (authState.isCheckingSession || !_onboardingChecked) {
      return const SplashScreen();
    }

    if (authState.isAuthenticated) {
      if (_showFeedSyncWarning) {
        return Stack(
          children: [
            const HomeScreen(),
            SafeArea(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Some feed records failed to sync. Check your connection.',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: _retryFeedSync,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      GestureDetector(
                        onTap: _dismissFeedSyncWarning,
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return const HomeScreen();
    }

    // First-time users see the onboarding carousel before login.
    if (!_hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    return const LoginScreen();
  }
}
