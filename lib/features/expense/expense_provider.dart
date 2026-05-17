import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/expense_service.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/uuid_generator.dart';

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
        operationId: generateUuidV4(),
      );
      AppLogger.info('Expense created successfully with ID: $expenseId');

      await loadExpenses();
      ref.invalidate(expenseSummaryProvider(cropId));
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
    String? pondId,
    bool changePondId = false,
  }) async {
    try {
      await expenseService.updateExpense(
        expenseId: expenseId,
        category: category,
        amount: amount,
        notes: notes,
        date: date,
        pondId: pondId,
        changePondId: changePondId,
      );

      await loadExpenses();
      ref.invalidate(expenseSummaryProvider(cropId));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await expenseService.deleteExpense(expenseId);

      await loadExpenses();
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

final expensesProvider = StateNotifierProvider.family.autoDispose<ExpenseNotifier,
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

final expenseSummaryProvider = StateNotifierProvider.family.autoDispose<
    ExpenseSummaryNotifier, AsyncValue<Map<String, dynamic>>, String>(
  (ref, cropId) {
    final expenseService = ref.watch(expenseServiceProvider);
    return ExpenseSummaryNotifier(expenseService, cropId);
  },
);

/// Farm-level expense total — keyed by farmId, used by the dashboard metrics provider.
final farmExpensesTotalProvider =
    FutureProvider.family.autoDispose<double, String>((ref, farmId) async {
  final svc = ref.watch(expenseServiceProvider);
  return svc.getTotalExpenses(farmId: farmId);
});
