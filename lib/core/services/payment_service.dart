import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

enum PaymentStatus { success, failed, cancelled }

class PaymentResult {
  final PaymentStatus status;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? error;

  const PaymentResult({
    required this.status,
    this.paymentId,
    this.orderId,
    this.signature,
    this.error,
  });
}

/// Wraps Razorpay checkout and Supabase edge-function calls.
///
/// Call [createOrder] → [openCheckout] → [verifyPayment] in sequence.
/// [openCheckout] converts the Razorpay callback API into a single Future.
class PaymentService {
  Razorpay? _razorpay;
  Completer<PaymentResult>? _completer;

  SupabaseClient get _db => Supabase.instance.client;

  Future<String> createOrder(int amountPaise, {String planType = 'PRO'}) async {
    final response = await _db.functions.invoke(
      'create-razorpay-order',
      body: {
        'amount': amountPaise,
        'currency': 'INR',
        'receipt': 'sub_${DateTime.now().millisecondsSinceEpoch}',
        'plan_type': planType,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['id'] == null) {
      throw Exception('Order creation failed: ${data['error'] ?? data}');
    }
    return data['id'] as String;
  }

  Future<PaymentResult> openCheckout({
    required String orderId,
    required int amountPaise,
    required String description,
    String? userName,
    String? userPhone,
  }) {
    _cleanup();
    _completer = Completer<PaymentResult>();

    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    _razorpay!.open({
      'key': AppConfig.razorpayKeyId,
      'amount': amountPaise,
      'name': 'Aqua Rythu',
      'description': description,
      'order_id': orderId,
      'prefill': {
        if (userName != null) 'name': userName,
        if (userPhone != null) 'contact': userPhone,
      },
      'theme': {'color': '#22C55E'},
    });

    return _completer!.future;
  }

  /// Sends payment proof to backend for server-side HMAC verification.
  Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required String planType,
    required double price,
  }) async {
    final response = await _db.functions.invoke(
      'verify-razorpay-payment',
      body: {
        'payment_id': paymentId,
        'order_id': orderId,
        'signature': signature,
        'plan_type': planType,
        'price': price,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception('Payment verification failed: ${data['error']}');
    }
    return data;
  }

  // ── T27: Backend pending payment persistence ─────────────────────────────────

  /// Saves payment proof to the `pending_payments` table so it survives
  /// app reinstalls or device switches. Fire-and-forget — a failure here must
  /// not block the main verify flow; SharedPreferences is still the fast path.
  Future<void> savePendingToBackend({
    required String paymentId,
    required String orderId,
    required String signature,
    required String planType,
    required double price,
  }) async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return;
      await _db.from('pending_payments').upsert(
        {
          'user_id': userId,
          'order_id': orderId,
          'payment_id': paymentId,
          'signature': signature,
          'plan_type': planType.toLowerCase(),
          'price': price,
          'status': 'pending',
        },
        onConflict: 'payment_id',
      );
    } catch (_) {
      // Best-effort — SharedPreferences already holds the proof.
    }
  }

  /// Fetches the most recent unverified pending payment from the backend.
  /// Returns null if none exists. Used by [SubscriptionNotifier.hydrateFromBackend]
  /// to surface a retry banner after reinstall or device switch.
  Future<Map<String, dynamic>?> fetchPendingFromBackend() async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await _db
          .from('pending_payments')
          .select()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  void _onSuccess(PaymentSuccessResponse response) {
    _completer?.complete(PaymentResult(
      status: PaymentStatus.success,
      paymentId: response.paymentId,
      orderId: response.orderId,
      signature: response.signature,
    ));
    _cleanup();
  }

  void _onError(PaymentFailureResponse response) {
    _completer?.complete(PaymentResult(
      status: PaymentStatus.failed,
      error: response.message ?? 'Payment failed',
    ));
    _cleanup();
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _completer?.complete(const PaymentResult(
      status: PaymentStatus.cancelled,
      error: 'Redirected to external wallet',
    ));
    _cleanup();
  }

  void _cleanup() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
