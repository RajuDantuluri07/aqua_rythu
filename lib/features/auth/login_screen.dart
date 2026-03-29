import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'auth_provider.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 10-digit number")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).signInWithOtp(phone);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pushNamed(context, AppRoutes.otp, arguments: phone);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.hXxl),
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
                // PHONE INPUT
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    borderRadius: AppRadius.rBase,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        "+91",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 24, color: theme.dividerColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            hintText: "Mobile Number",
                            border: InputBorder.none,
                            counterText: "",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.l),
                // SEND OTP BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("SEND OTP"),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // GOOGLE BUTTON
                OutlinedButton.icon(
                  onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
                  icon: const Icon(Icons.login),
                  label: const Text("CONTINUE WITH GOOGLE"),
                  style: theme.outlinedButtonTheme.style?.copyWith(
                    minimumSize: WidgetStateProperty.all(const Size(double.infinity, 56)),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("By continuing, you agree to ", style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    TextButton(
                      onPressed: () {},
                      child: const Text("TERMS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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