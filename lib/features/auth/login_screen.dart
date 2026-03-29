import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'auth_provider.dart';

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
    if (phone.length != 10) return;

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).signInWithOtp(phone);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pushNamed(context, AppRoutes.otp, arguments: phone);
      } else {
        final error = ref.read(authProvider).errorMessage;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Logo (PRD 4.1)
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 90,
                  errorBuilder: (_, __, ___) => const Icon(Icons.water_drop,
                      size: 90, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 40),

              // 2. Headline & Sub (PRD 4.1)
              const Text(
                "Welcome Back",
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 8),
              const Text(
                "Farmer-friendly digital aquaculture tool",
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // 3. +91 Phone Input (PRD 4.1)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text(
                      "+91",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    Container(
                        width: 1, height: 24, color: Colors.grey.shade300),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: "Mobile Number",
                          border: InputBorder.none,
                          counterText: "",
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Send OTP Button (PRD 4.1)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _phoneController.text.length == 10 && !_isLoading
                      ? _handleLogin
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Send OTP →",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 40),

              // 5. Social Proof (PRD 4.1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Stacked Avatars
                  SizedBox(
                    width: 70,
                    height: 30,
                    child: Stack(
                      children: [
                        _avatar(0, Colors.grey.shade300),
                        _avatar(20, Colors.grey.shade400),
                        _avatar(40, Colors.grey.shade500),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text("Trusted by 1000+ Farmers",
                      style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold)),
                ],
              ),

              const SizedBox(height: 60),

              // 6. Footer (PRD 4.1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                      onPressed: () {},
                      child: const Text("TERMS",
                          style: TextStyle(color: Colors.grey, fontSize: 12))),
                  const Text("•", style: TextStyle(color: Colors.grey)),
                  TextButton(
                      onPressed: () {},
                      child: const Text("PRIVACY",
                          style: TextStyle(color: Colors.grey, fontSize: 12))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(double left, Color color) {
    return Positioned(
      left: left,
      child: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white,
          child: CircleAvatar(radius: 12, backgroundColor: color)),
    );
  }
}
