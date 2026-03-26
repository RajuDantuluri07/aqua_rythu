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
  final FocusNode _focusNode = FocusNode();

  int _seconds = 59;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenForOtp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 59);
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

  void _resendOtp() {
    final phone = ModalRoute.of(context)?.settings.arguments as String?;

    if (phone != null) {
      ref.read(authProvider.notifier).signInWithOtp(phone);
    }

    _startTimer();
    _listenForOtp();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP Resent Successfully")),
    );
  }

  Future<void> _verifyOtp([String? code]) async {
    final otp = code ?? _otpController.text;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Enter complete OTP"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    _focusNode.unfocus();
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
    _focusNode.dispose();
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

    final phone = ModalRoute.of(context)?.settings.arguments as String? ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text("OTP Verification")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("Enter the code sent to +91 $phone", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            /// OTP INPUT
            PinFieldAutoFill(
              controller: _otpController,
              currentCode: _otpController.text,
              codeLength: 6,
              focusNode: _focusNode,
              autoFocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
              textInputAction: TextInputAction.done,
              decoration: BoxLooseDecoration(
                textStyle: const TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold),
                strokeColorBuilder: FixedColorBuilder(Theme.of(context).primaryColor),
                bgColorBuilder: FixedColorBuilder(Colors.white),
                radius: const Radius.circular(8),
                gapSpace: 12,
                strokeWidth: 1.5,
              ),
              onCodeChanged: (code) {
                setState(() {}); // Force rebuild to persist text across timer ticks
                if (code?.length == 6) {
                  _verifyOtp(code);
                }
              },
            ),

            const SizedBox(height: 20),

            /// TIMER & RESEND
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "00:${_seconds.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: _seconds == 0 ? Colors.grey : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _seconds == 0 ? _resendOtp : null,
                  child: const Text("Resend OTP"),
                ),
              ],
            ),

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