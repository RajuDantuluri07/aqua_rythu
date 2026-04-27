import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/core/models/subscription_model.dart';

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
  SubscriptionNotifier() : super(SubscriptionState(currentPlan: PlanType.FREE));

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

  void resetToFree() {
    state = state.copyWith(currentPlan: PlanType.FREE);
  }
}

// Provider
final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(),
);

// Convenience providers
final isProProvider = Provider<bool>((ref) => ref.watch(subscriptionProvider).isPro);
final planTypeProvider = Provider<PlanType>((ref) => ref.watch(subscriptionProvider).currentPlan);
