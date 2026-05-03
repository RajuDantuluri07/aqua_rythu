import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aqua_rythu/core/models/subscription_model.dart';
import 'package:aqua_rythu/core/services/payment_service.dart';
import 'package:aqua_rythu/core/services/subscription/subscription_gate.dart';
import 'package:aqua_rythu/core/services/subscription/subscription_service.dart';

// ── Payment phase (T22) ──────────────────────────────────────────────────────

enum PaymentPhase {
  idle,
  creatingOrder,
  awaitingPayment,
  verifying,
  success,
  failed,
}

// ── Pending verification record (T20) ────────────────────────────────────────

class PendingVerification {
  final String paymentId;
  final String orderId;
  final String signature;
  final String planType;
  final double price;

  const PendingVerification({
    required this.paymentId,
    required this.orderId,
    required this.signature,
    required this.planType,
    required this.price,
  });

  factory PendingVerification.fromJson(Map<String, dynamic> j) =>
      PendingVerification(
        paymentId: j['payment_id'] as String,
        orderId: j['order_id'] as String,
        signature: j['signature'] as String,
        planType: j['plan_type'] as String,
        price: (j['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'payment_id': paymentId,
        'order_id': orderId,
        'signature': signature,
        'plan_type': planType,
        'price': price,
      };
}

// ── State ────────────────────────────────────────────────────────────────────

class SubscriptionState {
  final PlanType currentPlan;
  final bool isLoading;
  final PaymentPhase paymentPhase;
  final PendingVerification? pendingVerification;
  final String? error;

  const SubscriptionState({
    required this.currentPlan,
    this.isLoading = false,
    this.paymentPhase = PaymentPhase.idle,
    this.pendingVerification,
    this.error,
  });

  SubscriptionState copyWith({
    PlanType? currentPlan,
    bool? isLoading,
    PaymentPhase? paymentPhase,
    PendingVerification? pendingVerification,
    bool clearPending = false,
    String? error,
  }) {
    return SubscriptionState(
      currentPlan: currentPlan ?? this.currentPlan,
      isLoading: isLoading ?? this.isLoading,
      paymentPhase: paymentPhase ?? this.paymentPhase,
      pendingVerification:
          clearPending ? null : pendingVerification ?? this.pendingVerification,
      error: error,
    );
  }

  bool get isPro => currentPlan == PlanType.PRO;
  bool get isFree => currentPlan == PlanType.FREE;
  bool get hasPendingVerification => pendingVerification != null;
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  static const _pendingKey = 'pending_payment_verification';
  final Ref _ref;

  SubscriptionNotifier(this._ref)
      : super(const SubscriptionState(currentPlan: PlanType.FREE)) {
    SubscriptionGate.setPro(false);
    _loadPendingVerification();
  }

  @override
  set state(SubscriptionState value) {
    super.state = value;
    SubscriptionGate.setPro(value.isPro);
  }

  // ── Boot hydration ──────────────────────────────────────────────────────────

  Future<void> hydrateFromBackend() async {
    try {
      final subscription = await _ref
          .read(subscriptionServiceProvider)
          .getCurrentSubscription();
      state = state.copyWith(
        currentPlan: (subscription?.isPro == true) ? PlanType.PRO : PlanType.FREE,
      );
    } catch (_) {
      // Silent — user stays FREE; manual restore available.
    }

    // T27: If no local pending proof, check the backend — covers reinstalls
    // and device switches where SharedPreferences was wiped.
    if (state.pendingVerification == null && !state.isPro) {
      try {
        final row = await _ref
            .read(paymentServiceProvider)
            .fetchPendingFromBackend();
        if (row != null) {
          final pending = PendingVerification(
            paymentId: row['payment_id'] as String,
            orderId: row['order_id'] as String,
            signature: row['signature'] as String,
            planType: row['plan_type'] as String,
            price: (row['price'] as num).toDouble(),
          );
          await _savePendingVerification(pending);
          state = state.copyWith(pendingVerification: pending);
        }
      } catch (_) {}
    }
  }

  // ── Restore purchase ────────────────────────────────────────────────────────

  Future<bool> restorePurchase() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final subscription = await _ref
          .read(subscriptionServiceProvider)
          .getCurrentSubscription();
      if (subscription?.isPro == true) {
        state = state.copyWith(currentPlan: PlanType.PRO, isLoading: false);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'No active PRO subscription found for this account.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── Initiate payment ────────────────────────────────────────────────────────

  Future<void> initiatePayment(PlanType plan) async {
    final amountPaise = plan == PlanType.PRO ? 99900 : 299900;
    final price = plan == PlanType.PRO ? 999.0 : 2999.0;
    final description = plan == PlanType.PRO
        ? 'PRO Subscription (Per Crop)'
        : 'Business Subscription (Yearly)';

    final paymentService = _ref.read(paymentServiceProvider);
    final user = Supabase.instance.client.auth.currentUser;

    // Phase 1: Creating order
    state = state.copyWith(
      paymentPhase: PaymentPhase.creatingOrder,
      isLoading: true,
      error: null,
    );

    try {
      final orderId = await paymentService.createOrder(amountPaise, planType: plan.name);

      // Phase 2: Razorpay sheet is open
      state = state.copyWith(paymentPhase: PaymentPhase.awaitingPayment);

      final result = await paymentService.openCheckout(
        orderId: orderId,
        amountPaise: amountPaise,
        description: description,
        userName: user?.userMetadata?['name'] as String?,
        userPhone: user?.phone,
      );

      if (result.status != PaymentStatus.success) {
        state = state.copyWith(
          paymentPhase: PaymentPhase.failed,
          isLoading: false,
          error: result.error ?? 'Payment was not completed.',
        );
        return;
      }

      // Phase 3: Payment captured — persist proof BEFORE hitting the network
      // so that a DB failure never loses the user's payment (T20).
      final pending = PendingVerification(
        paymentId: result.paymentId!,
        orderId: result.orderId!,
        signature: result.signature!,
        planType: plan.name,
        price: price,
      );
      // Fast path: SharedPreferences (survives crash)
      await _savePendingVerification(pending);
      // Durable path: backend DB (survives reinstall / device switch) (T27)
      await _ref.read(paymentServiceProvider).savePendingToBackend(
        paymentId: pending.paymentId,
        orderId: pending.orderId,
        signature: pending.signature,
        planType: pending.planType,
        price: pending.price,
      );
      state = state.copyWith(
        paymentPhase: PaymentPhase.verifying,
        pendingVerification: pending,
      );

      await _runVerification(pending, plan);
    } catch (e) {
      state = state.copyWith(
        paymentPhase: PaymentPhase.failed,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // ── Retry verification (T20) ────────────────────────────────────────────────

  Future<void> retryVerification() async {
    final pending = state.pendingVerification;
    if (pending == null) return;

    final plan = PlanType.values.firstWhere(
      (p) => p.name.toLowerCase() == pending.planType.toLowerCase(),
      orElse: () => PlanType.PRO,
    );

    state = state.copyWith(
      paymentPhase: PaymentPhase.verifying,
      isLoading: true,
      error: null,
    );

    await _runVerification(pending, plan);
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<void> _runVerification(PendingVerification pending, PlanType plan) async {
    try {
      await _ref.read(paymentServiceProvider).verifyPayment(
        paymentId: pending.paymentId,
        orderId: pending.orderId,
        signature: pending.signature,
        planType: pending.planType,
        price: pending.price,
      );

      // Verified — clear pending and activate PRO
      await _clearPendingVerification();
      state = state.copyWith(
        currentPlan: plan,
        paymentPhase: PaymentPhase.success,
        isLoading: false,
        clearPending: true,
      );
    } catch (e) {
      // Verification failed — keep pending so user can retry (T20)
      state = state.copyWith(
        paymentPhase: PaymentPhase.failed,
        isLoading: false,
        error: 'Verification failed. Your payment is safe — tap "Retry" to activate PRO.',
      );
    }
  }

  Future<void> _savePendingVerification(PendingVerification pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, jsonEncode(pending.toJson()));
    } catch (_) {}
  }

  Future<void> _clearPendingVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
    } catch (_) {}
  }

  Future<void> _loadPendingVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null) return;
      final pending = PendingVerification.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // Surface the pending state so the UI can show a retry banner
      state = state.copyWith(pendingVerification: pending);
    } catch (_) {}
  }

  void resetToFree() {
    state = state.copyWith(currentPlan: PlanType.FREE);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final paymentServiceProvider =
    Provider<PaymentService>((ref) => PaymentService());

final subscriptionServiceProvider =
    Provider<SubscriptionService>((ref) => SubscriptionService());

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(ref),
);

final isProProvider =
    Provider<bool>((ref) => ref.watch(subscriptionProvider).isPro);

final planTypeProvider =
    Provider<PlanType>((ref) => ref.watch(subscriptionProvider).currentPlan);
