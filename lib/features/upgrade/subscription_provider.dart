import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aqua_rythu/core/models/subscription_model.dart';
import 'package:aqua_rythu/core/models/subscription_plans.dart';
import 'package:aqua_rythu/core/services/payment_service.dart';
import 'package:aqua_rythu/core/services/subscription_gate.dart';
import 'package:aqua_rythu/core/services/subscription_service.dart';
import 'package:aqua_rythu/core/utils/logger.dart';

// ── Payment phase (T22) ──────────────────────────────────────────────────────

enum PaymentPhase {
  idle,
  creatingOrder,
  awaitingPayment,
  verifying,
  success,
  failed,
  cancelled,
  externalWalletPending,
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
  final bool isHydrated;

  const SubscriptionState({
    required this.currentPlan,
    this.isLoading = false,
    this.paymentPhase = PaymentPhase.idle,
    this.pendingVerification,
    this.error,
    this.isHydrated = false,
  });

  SubscriptionState copyWith({
    PlanType? currentPlan,
    bool? isLoading,
    PaymentPhase? paymentPhase,
    PendingVerification? pendingVerification,
    bool clearPending = false,
    String? error,
    bool? isHydrated,
  }) {
    return SubscriptionState(
      currentPlan: currentPlan ?? this.currentPlan,
      isLoading: isLoading ?? this.isLoading,
      paymentPhase: paymentPhase ?? this.paymentPhase,
      pendingVerification:
          clearPending ? null : pendingVerification ?? this.pendingVerification,
      error: error,
      isHydrated: isHydrated ?? this.isHydrated,
    );
  }

  bool get isPro => currentPlan == PlanType.pro;
  bool get isFree => currentPlan == PlanType.free;
  bool get hasPendingVerification => pendingVerification != null;
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  static const _pendingKey = 'pending_payment_verification';
  final Ref _ref;

  SubscriptionNotifier(this._ref)
      : super(const SubscriptionState(currentPlan: PlanType.free, isHydrated: false)) {
    SubscriptionGate.setPro(false);
    _loadPendingVerification();
    _initializeFromBackend();
  }

  /// Initializes subscription state from backend during app startup
  Future<void> _initializeFromBackend() async {
    await hydrateFromBackend();
    state = state.copyWith(isHydrated: true);
    // Resolve the boot-race gate so MasterFeedEngine.orchestrateForPond()
    // can proceed with the correct PRO/FREE status.
    SubscriptionGate.setHydrated();
  }

  @override
  set state(SubscriptionState value) {
    super.state = value;
    SubscriptionGate.setPro(value.isPro);
  }

  // ── Boot hydration ──────────────────────────────────────────────────────────

  Future<void> hydrateFromBackend() async {
    try {
      final entitlement = await _ref
          .read(subscriptionServiceProvider)
          .getActiveEntitlement();
      state = state.copyWith(
        currentPlan: entitlement != null ? PlanType.pro : PlanType.free,
      );
    } catch (e) {
      AppLogger.error('Subscription hydration failed: $e');
      // User stays FREE; manual restore available via settings.
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
      } catch (e) {
        AppLogger.error('Failed to fetch pending verification from backend: $e');
      }
    }

    // Always mark hydration complete so the feed engine never times out and
    // silently falls back to FREE for PRO users on slow networks.
    state = state.copyWith(isHydrated: true);
    SubscriptionGate.setHydrated();
  }

  // ── Restore purchase ────────────────────────────────────────────────────────

  Future<bool> restorePurchase() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Use server-authoritative RPC — not the client-side SELECT path which
      // can be fooled by local clock skew or stale RLS data.
      final entitlement = await _ref
          .read(subscriptionServiceProvider)
          .getActiveEntitlement();
      if (entitlement != null) {
        state = state.copyWith(currentPlan: PlanType.pro, isLoading: false);
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

  Future<void> initiatePayment(SubscriptionPlan plan) async {
    final amountPaise = plan.amountPaise;
    final price = plan.price;
    final description = plan.description;

    final paymentService = _ref.read(paymentServiceProvider);
    final user = Supabase.instance.client.auth.currentUser;

    // Phase 1: Creating order
    state = state.copyWith(
      paymentPhase: PaymentPhase.creatingOrder,
      isLoading: true,
      error: null,
    );

    try {
      final orderId = await paymentService.createOrder(amountPaise, planType: plan.id);

      // Log that payment was initiated (order exists, gateway not yet opened)
      paymentService.logClientEvent(status: 'initiated', orderId: orderId);

      // Phase 2: Razorpay sheet is open
      state = state.copyWith(paymentPhase: PaymentPhase.awaitingPayment);

      final result = await paymentService.openCheckout(
        orderId: orderId,
        amountPaise: amountPaise,
        description: description,
        userName: user?.userMetadata?['name'] as String?,
        userPhone: user?.phone,
      );

      if (result.status == PaymentStatus.cancelled) {
        paymentService.logClientEvent(status: 'cancelled', orderId: orderId);
        state = state.copyWith(
          paymentPhase: PaymentPhase.cancelled,
          isLoading: false,
          error: null,
        );
        return;
      }

      if (result.status == PaymentStatus.externalWalletPending) {
        paymentService.logClientEvent(status: 'external_wallet_pending', orderId: orderId);
        state = state.copyWith(
          paymentPhase: PaymentPhase.externalWalletPending,
          isLoading: false,
          error: null,
        );
        return;
      }

      if (result.status == PaymentStatus.failed) {
        paymentService.logClientEvent(
          status: 'failed',
          orderId: orderId,
          errorMessage: result.error,
        );
        state = state.copyWith(
          paymentPhase: PaymentPhase.failed,
          isLoading: false,
          error: result.error ?? 'Payment failed. Please try again.',
        );
        return;
      }

      // Phase 3: Payment captured — persist proof BEFORE hitting the network
      // so that a DB failure never loses the user's payment (T20).
      final pending = PendingVerification(
        paymentId: result.paymentId!,
        orderId: result.orderId!,
        signature: result.signature!,
        planType: plan.id,
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

      await _runVerification(pending);
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

    state = state.copyWith(
      paymentPhase: PaymentPhase.verifying,
      isLoading: true,
      error: null,
    );

    await _runVerification(pending);
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<void> _runVerification(PendingVerification pending) async {
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
        currentPlan: PlanType.pro,
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
    } catch (e) {
      AppLogger.error('Failed to save pending verification: $e');
    }
  }

  Future<void> _clearPendingVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
    } catch (e) {
      AppLogger.error('Failed to clear pending verification: $e');
    }
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
    } catch (e) {
      AppLogger.error('Failed to load pending verification: $e');
    }
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
