import 'package:flutter/material.dart';
import 'package:aqua_rythu/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  void _onLogin() {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid 10-digit mobile number"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    Navigator.pushNamed(context, AppRoutes.otp);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background color is handled by AppTheme
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Branding
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
              ),

              const SizedBox(height: 32),

              // Title using AppTheme text styles
              Text(
                "Welcome Back",
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 8),

              const Text(
                "Enter your mobile number to log in",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // Input Field
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  hintText: "Mobile Number",
                  prefixIcon: Icon(Icons.phone),
                  prefixText: "+91 ",
                  counterText: "", // Hides the character counter
                ),
              ),

              const SizedBox(height: 24),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onLogin,
                  child: const Text("Get OTP"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}