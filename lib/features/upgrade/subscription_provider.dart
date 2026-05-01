import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqua_rythu/core/models/subscription_model.dart';
import 'package:aqua_rythu/core/services/subscription_gate.dart';

// Mock subscription state - in real app this would come from backend/API
class SubscriptionState {
  final PlanType currentPlan;
  final bool isLoading;
  final String? error;

  SubscriptionState({
    required this.currentPlan,
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    PlanType? currentPlan,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      currentPlan: currentPlan ?? this.currentPlan,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get isPro => currentPlan == PlanType.PRO;
  bool get isFree => currentPlan == PlanType.FREE;
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier()
      : super(SubscriptionState(currentPlan: PlanType.FREE)) {
    SubscriptionGate.setPro(false);
    _loadSubscription();
  }

  @override
  set state(SubscriptionState value) {
    super.state = value;
    SubscriptionGate.setPro(value.isPro);
  }

  Future<void> upgradeToPro() async {
    state = state.copyWith(isLoading: true);

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // In real app, this would call payment API and update backend
      state = state.copyWith(
        currentPlan: PlanType.PRO,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Unlock PRO
    state = state.copyWith(
      currentPlan: PlanType.PRO,
      isLoading: false,
    );

    // Update gate
    SubscriptionGate.setPro(true);

    // Persist locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_user', true);
  }

  Future<void> _loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = prefs.getBool('is_pro_user') ?? false;

    if (isPro) {
      SubscriptionGate.setPro(true);
      state = state.copyWith(currentPlan: PlanType.PRO);
    }
  }

  Future<void> loadSubscription() async {
    await _loadSubscription();
  }

  void resetToFree() {
    state = state.copyWith(currentPlan: PlanType.FREE);
  }
}

// Provider
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(),
);

// Convenience providers
final isProProvider =
    Provider<bool>((ref) => ref.watch(subscriptionProvider).isPro);
final planTypeProvider =
    Provider<PlanType>((ref) => ref.watch(subscriptionProvider).currentPlan);
