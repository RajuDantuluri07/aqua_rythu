import 'package:flutter/material.dart';
import 'package:aqua_rythu/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  void _onLogin() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid 10-digit mobile number"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    // Simulate network delay for premium feel
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);
    
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E9), // Light green tint
              Color(0xFFFFFFFF), // White
              Color(0xFFF1F8E9), // Very light green
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Branding with subtle shadow
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.water_drop_rounded,
                      size: 72,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  Text(
                    "AquaRythu",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Smart Aquaculture Management",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Input Card
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "Mobile Number",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Colors.grey),
                        prefixText: "+91  ",
                        prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        counterText: "",
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: Theme.of(context).primaryColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              "Get OTP",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Footer Text
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black45, fontSize: 13, height: 1.5),
                      children: [
                        const TextSpan(text: "By logging in, you agree to our\n"),
                        TextSpan(
                          text: "Terms of Service",
                          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: " & "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}