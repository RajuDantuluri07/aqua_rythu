import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/expense_service.dart';
import '../../core/utils/logger.dart';

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final ExpenseService expenseService;
  final String cropId;
  final Ref ref;

  ExpenseNotifier({
    required this.ref,
    required this.expenseService,
    required this.cropId,
  }) : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    try {
      final expenses = await expenseService.getExpenses(cropId: cropId);
      state = AsyncValue.data(expenses);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addExpense({
    required String farmId,
    String? pondId,
    required ExpenseCategory category,
    required double amount,
    String? notes,
    DateTime? date,
  }) async {
    try {
      final expenseId = await expenseService.createExpense(
        farmId: farmId,
        cropId: cropId,
        pondId: pondId,
        category: category,
        amount: amount,
        notes: notes,
        date: date,
      );
      AppLogger.info('Expense created successfully with ID: $expenseId');

      // Refresh the expenses list with explicit wait
      await loadExpenses();
      AppLogger.info('Expenses reloaded after creation');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add expense: $e\nStackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateExpense({
    required String expenseId,
    ExpenseCategory? category,
    double? amount,
    String? notes,
    DateTime? date,
  }) async {
    try {
      await expenseService.updateExpense(
        expenseId: expenseId,
        category: category,
        amount: amount,
        notes: notes,
        date: date,
      );

      // Refresh the expenses list
      await loadExpenses();

      // Invalidate dependent providers to ensure UI sync
      ref.invalidate(expensesProvider(cropId));
      ref.invalidate(expenseSummaryProvider(cropId));
    } catch (e) {
      // Let the UI handle the error
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await expenseService.deleteExpense(expenseId);

      // Refresh the expenses list
      await loadExpenses();

      // Invalidate dependent providers to ensure UI sync
      ref.invalidate(expensesProvider(cropId));
      ref.invalidate(expenseSummaryProvider(cropId));
    } catch (e) {
      // Let the UI handle the error
      rethrow;
    }
  }
}

class ExpenseSummaryNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
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

  Future<List<Expense>> getIndividualExpenses({DateTime? date}) async {
    try {
      return await _expenseService.getExpenses(
        cropId: cropId,
        startDate: date,
        endDate: date,
      );
    } catch (e) {
      return [];
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

final expensesProvider = StateNotifierProvider.family<ExpenseNotifier,
    AsyncValue<List<Expense>>, String>(
  (ref, cropId) {
    final expenseService = ref.watch(expenseServiceProvider);
    return ExpenseNotifier(
      ref: ref,
      expenseService: expenseService,
      cropId: cropId,
    );
  },
);

final expenseSummaryProvider = StateNotifierProvider.family<
    ExpenseSummaryNotifier, AsyncValue<Map<String, dynamic>>, String>(
  (ref, cropId) {
    final expenseService = ref.watch(expenseServiceProvider);
    return ExpenseSummaryNotifier(expenseService, cropId);
  },
);
