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
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());

  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

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
    await SmsAutoFill().listenForCode;

    SmsAutoFill().code.listen((code) {
      if (code.length == 6) {
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = code[i];
        }
        _verifyOtp();
      }
    });
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text("Enter complete OTP"),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).login(_otp);

    // The listener below will handle navigation/errors.
    // We just need to stop the loading indicator if the widget is still mounted.
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: const InputDecoration(
          counterText: "",
        ),
        onChanged: (value) => _onOtpChanged(index, value),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes for navigation or showing errors.
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
            context, AppRoutes.dashboard, (route) => false);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text("OTP Verification")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, _otpBox),
            ),

            const SizedBox(height: 20),

            Text("00:${_seconds.toString().padLeft(2, '0')}"),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Verify"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}