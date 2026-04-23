import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'forgot_password_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/logger.dart';
import '../../core/services/admin_security_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;

  // Admin access tracking
  int _logoClickCount = 0;
  DateTime? _lastLogoClickTime;
  static const Duration _clickResetTime = Duration(seconds: 3);
  static const int _requiredClicks = 5;

  void _handleLogoClick() {
    final now = DateTime.now();

    // Reset counter if too much time has passed
    if (_lastLogoClickTime != null &&
        now.difference(_lastLogoClickTime!) > _clickResetTime) {
      _logoClickCount = 0;
    }

    _logoClickCount++;
    _lastLogoClickTime = now;

    // Check if required clicks reached
    if (_logoClickCount >= _requiredClicks) {
      _logoClickCount = 0;
      _showAdminPasscodeDialog();
    }
  }

  void _showAdminPasscodeDialog() {
    final TextEditingController passcodeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Admin Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter admin passcode:'),
            const SizedBox(height: 16),
            TextField(
              controller: passcodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: '4-digit passcode',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final passcode = passcodeController.text.trim();
              Navigator.of(dialogContext).pop();

              if (passcode.isEmpty) return;

              try {
                final adminService = AdminSecurityService();
                final isValid =
                    await adminService.validateAdminAccess(passcode);

                if (mounted) {
                  if (isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Admin access granted! Session active for 15 minutes.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid passcode'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Authentication failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Guard: don't submit while a request is already in flight
    if (ref.read(authProvider).isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid email address")),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    AppLogger.debug("Auth: sign-in started");
    final authNotifier = ref.read(authProvider.notifier);

    _isLogin
        ? await authNotifier.signIn(email, password)
        : await authNotifier.signUp(email, password);

    final user = Supabase.instance.client.auth.currentUser;
    AppLogger.debug("Auth: user after sign-in: ${user?.id ?? 'null'}");
    // Navigation is handled declaratively by AuthGate — do not push here.
  }

  @override
  Widget build(BuildContext context) {
    // Show errors only — navigation is owned by AuthGate (declarative).
    ref.listen<AppAuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                // Hero logo for smooth transition from SplashScreen
                GestureDetector(
                  onTap: _handleLogoClick,
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 90,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.water_drop_rounded,
                        size: 60,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  "AquaRythu",
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.primaryColor,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  "Smart Shrimp Farming",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.hXxl),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                // LOGIN / SIGN UP BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : Text(_isLogin ? "LOGIN" : "SIGN UP"),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin
                          ? "Don't have an account? Sign Up"
                          : "Already have an account? Login"),
                    ),
                    TextButton(
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const ForgotPasswordDialog()),
                      child: const Text("Forgot Password?"),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("By continuing, you agree to ",
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 12)),
                    TextButton(
                      onPressed: () {},
                      child: const Text("TERMS",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                // AVATAR STACK (optional UI)
                SizedBox(
                  height: 60,
                  child: Stack(
                    children: [
                      _avatar(0, Colors.grey.shade300),
                      _avatar(30, Colors.grey.shade400),
                      _avatar(60, Colors.grey.shade500),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(double left, Color color) {
    return Positioned(
      left: left,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: color,
      ),
    );
  }
}
