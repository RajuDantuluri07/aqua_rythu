import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/expense_service.dart';

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final ExpenseService _expenseService;
  final String cropId;

  ExpenseNotifier(this._expenseService, this.cropId) : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    try {
      final expenses = await _expenseService.getExpenses(cropId: cropId);
      state = AsyncValue.data(expenses);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addExpense({
    required String farmId,
    required ExpenseCategory category,
    required double amount,
    String? notes,
    DateTime? date,
  }) async {
    try {
      await _expenseService.createExpense(
        farmId: farmId,
        cropId: cropId,
        category: category,
        amount: amount,
        notes: notes,
        date: date,
      );
      
      // Refresh the expenses list
      await loadExpenses();
    } catch (e) {
      // Let the UI handle the error
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await _expenseService.deleteExpense(expenseId);
      
      // Refresh the expenses list
      await loadExpenses();
    } catch (e) {
      // Let the UI handle the error
      rethrow;
    }
  }
}

class ExpenseSummaryNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final ExpenseService _expenseService;
  final String cropId;

  ExpenseSummaryNotifier(this._expenseService, this.cropId) 
      : super(const AsyncValue.loading()) {
    loadSummary();
  }

  Future<void> loadSummary() async {
    state = const AsyncValue.loading();
    try {
      final daily = await _expenseService.getDailyExpenses(cropId);
      final weekly = await _expenseService.getWeeklyExpenses(cropId);
      final monthly = await _expenseService.getMonthlyExpenses(cropId);
      final total = await _expenseService.getTotalExpenses(cropId: cropId);

      state = AsyncValue.data({
        'daily': daily,
        'weekly': weekly,
        'monthly': monthly,
        'total': total,
      });
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await loadSummary();
  }
}

// Providers
final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService();
});

final expensesProvider = StateNotifierProvider.family<ExpenseNotifier, AsyncValue<List<Expense>>, String>(
  (ref, cropId) {
    final expenseService = ref.watch(expenseServiceProvider);
    return ExpenseNotifier(expenseService, cropId);
  },
);

final expenseSummaryProvider = StateNotifierProvider.family<ExpenseSummaryNotifier, AsyncValue<Map<String, dynamic>>, String>(
  (ref, cropId) {
    final expenseService = ref.watch(expenseServiceProvider);
    return ExpenseSummaryNotifier(expenseService, cropId);
  },
);
