import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/expense_service.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/uuid_generator.dart';

// ── Filter ────────────────────────────────────────────────────────────────────

@immutable
class ExpenseFilter {
  final ExpenseCategory? category;
  final String? pondId;
  final DateTimeRange? dateRange;

  const ExpenseFilter({this.category, this.pondId, this.dateRange});

  bool get isActive => category != null || pondId != null || dateRange != null;

  int get activeCount =>
      [category, pondId, dateRange].where((f) => f != null).length;

  bool matches(Expense expense) {
    if (category != null && expense.category != category) return false;
    if (pondId != null && expense.pondId != pondId) return false;
    if (dateRange != null) {
      final d = DateUtils.dateOnly(expense.date);
      final start = DateUtils.dateOnly(dateRange!.start);
      final end = DateUtils.dateOnly(dateRange!.end);
      if (d.isBefore(start) || d.isAfter(end)) return false;
    }
    return true;
  }

  ExpenseFilter copyWith({
    Object? category = _sentinel,
    Object? pondId = _sentinel,
    Object? dateRange = _sentinel,
  }) =>
      ExpenseFilter(
        category: category == _sentinel
            ? this.category
            : category as ExpenseCategory?,
        pondId: pondId == _sentinel ? this.pondId : pondId as String?,
        dateRange: dateRange == _sentinel
            ? this.dateRange
            : dateRange as DateTimeRange?,
      );

  ExpenseFilter cleared() => const ExpenseFilter();

  @override
  bool operator ==(Object other) =>
      other is ExpenseFilter &&
      other.category == category &&
      other.pondId == pondId &&
      other.dateRange == dateRange;

  @override
  int get hashCode => Object.hash(category, pondId, dateRange);
}

const _sentinel = Object();

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
      unawaited(AnalyticsService.instance.logExpenseAdded(
        farmId: farmId,
        category: category.name,
        amount: amount,
      ));

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
      unawaited(AnalyticsService.instance.logExpenseDeleted());

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

// ── History / Filter providers (crop-scoped) ─────────────────────────────────

/// Active filter for the expense history screen, keyed by cropId.
final expenseFilterProvider =
    StateProvider.family.autoDispose<ExpenseFilter, String>(
  (ref, cropId) => const ExpenseFilter(),
);

/// All expenses for a crop, with the active filter applied client-side.
final filteredExpensesProvider =
    Provider.family.autoDispose<AsyncValue<List<Expense>>, String>(
  (ref, cropId) {
    final filter = ref.watch(expenseFilterProvider(cropId));
    return ref.watch(expensesProvider(cropId)).whenData(
          (all) => filter.isActive ? all.where(filter.matches).toList() : all,
        );
  },
);

// ── Farm-scoped history providers ─────────────────────────────────────────────
// Used by ExpenseHistoryScreen so farm-wide expenses (null cropId) are visible.

class _FarmExpensesNotifier
    extends StateNotifier<AsyncValue<List<Expense>>> {
  final ExpenseService _svc;
  final String farmId;

  _FarmExpensesNotifier(this._svc, this.farmId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final expenses = await _svc.getExpenses(farmId: farmId);
      // Sort newest first (service returns by date desc already, but be safe).
      expenses.sort((a, b) => b.date.compareTo(a.date));
      state = AsyncValue.data(expenses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();
}

final farmExpensesListProvider = StateNotifierProvider.family
    .autoDispose<_FarmExpensesNotifier, AsyncValue<List<Expense>>, String>(
  (ref, farmId) => _FarmExpensesNotifier(ExpenseService(), farmId),
);

/// Active filter for the farm-level history screen, keyed by farmId.
final farmExpenseFilterProvider =
    StateProvider.family.autoDispose<ExpenseFilter, String>(
  (ref, farmId) => const ExpenseFilter(),
);

/// Farm-wide expenses with filter applied.
final filteredFarmExpensesProvider =
    Provider.family.autoDispose<AsyncValue<List<Expense>>, String>(
  (ref, farmId) {
    final filter = ref.watch(farmExpenseFilterProvider(farmId));
    return ref.watch(farmExpensesListProvider(farmId)).whenData(
          (all) => filter.isActive ? all.where(filter.matches).toList() : all,
        );
  },
);
