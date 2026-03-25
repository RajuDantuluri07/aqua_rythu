import 'package:sms_autofill/sms_autofill.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  int _seconds = 59;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenForOtp();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        timer.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _listenForOtp() async {
    await SmsAutoFill().listenForCode();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Enter complete OTP"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await ref.read(authProvider.notifier).login(otp);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    SmsAutoFill().unregisterListener();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// ✅ LISTEN TO AUTH STATE
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else if (next.isAuthenticated) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboard,
          (route) => false,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text("OTP Verification")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            /// OTP INPUT
            PinFieldAutoFill(
              controller: _otpController,
              codeLength: 6,
              decoration: BoxLooseDecoration(
                strokeColorBuilder: FixedColorBuilder(Theme.of(context).primaryColor),
                bgColorBuilder: FixedColorBuilder(Colors.white),
                radius: Radius.circular(8),
                gapSpace: 12,
                strokeWidth: 1.5,
              ),
              onCodeChanged: (code) {
                if (code?.length == 6) {
                  _verifyOtp();
                }
              },
            ),

            const SizedBox(height: 20),

            /// TIMER
            Text("00:${_seconds.toString().padLeft(2, '0')}"),

            const SizedBox(height: 20),

            /// VERIFY BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Verify"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}