import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import '../utils/logger.dart';

/// Validates numeric fields and logs issues instead of silent defaults
double _validateNumericField(dynamic value, String fieldName,
    [double defaultValue = 0.0]) {
  if (value == null) {
    AppLogger.error('Missing required field: $fieldName');
    return defaultValue;
  }

  if (value is! num) {
    AppLogger.error(
        'Invalid type for $fieldName: expected number, got ${value.runtimeType}');
    return defaultValue;
  }

  final numValue = value as num;
  if (numValue.isNaN) {
    AppLogger.error('Invalid value for $fieldName: NaN');
    return defaultValue;
  }

  if (numValue < 0) {
    AppLogger.warn('Negative value for $fieldName: $numValue, using 0.0');
    return 0.0;
  }

  return numValue.toDouble();
}

/// Validates string fields and logs issues instead of silent defaults
String _validateStringField(dynamic value, String fieldName,
    [String defaultValue = 'other']) {
  if (value == null) {
    AppLogger.error('Missing required field: $fieldName');
    return defaultValue;
  }

  if (value is! String) {
    AppLogger.error(
        'Invalid type for $fieldName: expected string, got ${value.runtimeType}');
    return defaultValue;
  }

  final strValue = value as String;
  if (strValue.isEmpty) {
    AppLogger.warn('Empty string for $fieldName, using default: $defaultValue');
    return defaultValue;
  }

  return strValue;
}

class ExpenseService {
  final supabase = Supabase.instance.client;

  Future<String> createExpense({
    required String farmId,
    required String cropId,
    required ExpenseCategory category,
    required double amount,
    String? notes,
    DateTime? date,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final response = await supabase
          .from('expenses')
          .insert({
            'user_id': user.id,
            'farm_id': farmId,
            'crop_id': cropId,
            'category': category.value,
            'amount': amount,
            'notes': notes,
            'date': date?.toIso8601String().split('T')[0] ??
                DateTime.now().toIso8601String().split('T')[0],
          })
          .select()
          .single();

      AppLogger.info('Created expense: ${response['id']}');
      return response['id'].toString();
    } catch (e) {
      AppLogger.error('Failed to create expense: $e');
      rethrow;
    }
  }

  Future<List<Expense>> getExpenses({
    String? cropId,
    String? farmId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      var query = supabase.from('expenses').select('*').eq('user_id', user.id);

      if (cropId != null) {
        query = query.eq('crop_id', cropId);
      }
      if (farmId != null) {
        query = query.eq('farm_id', farmId);
      }
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String().split('T')[0]);
      }

      final result = await query.order('date', ascending: false).limit(limit);
      return result.map((item) => Expense.fromMap(item)).toList();
    } catch (e) {
      AppLogger.error('Failed to get expenses: $e');
      return [];
    }
  }

  Future<List<ExpenseSummary>> getDailyExpenses(String cropId,
      {DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final result = await supabase
          .from('expenses')
          .select('category, amount')
          .eq('user_id', user.id)
          .eq('crop_id', cropId)
          .eq('date', targetDate.toIso8601String().split('T')[0]);

      final categoryTotals = <String, double>{};
      final categoryCounts = <String, int>{};

      for (final item in result) {
        final category =
            _validateStringField(item['category'], 'category', 'other');
        final amount = _validateNumericField(item['amount'], 'amount', 0.0);

        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      return categoryTotals.entries.map((entry) {
        return ExpenseSummary(
          category: entry.key,
          totalAmount: entry.value,
          count: categoryCounts[entry.key] ?? 0,
        );
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get daily expenses: $e');
      return [];
    }
  }

  Future<List<ExpenseSummary>> getWeeklyExpenses(String cropId,
      {DateTime? weekStart}) async {
    try {
      final targetWeekStart = weekStart ??
          DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      final targetWeekEnd = targetWeekStart.add(const Duration(days: 6));
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final result = await supabase
          .from('expenses')
          .select('category, amount')
          .eq('user_id', user.id)
          .eq('crop_id', cropId)
          .gte('date', targetWeekStart.toIso8601String().split('T')[0])
          .lte('date', targetWeekEnd.toIso8601String().split('T')[0]);

      final categoryTotals = <String, double>{};
      final categoryCounts = <String, int>{};

      for (final item in result) {
        final category =
            _validateStringField(item['category'], 'category', 'other');
        final amount = _validateNumericField(item['amount'], 'amount', 0.0);

        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      return categoryTotals.entries.map((entry) {
        return ExpenseSummary(
          category: entry.key,
          totalAmount: entry.value,
          count: categoryCounts[entry.key] ?? 0,
        );
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get weekly expenses: $e');
      return [];
    }
  }

  Future<List<WeeklyExpenseSummary>> getMonthlyExpenses(String cropId,
      {DateTime? monthStart}) async {
    try {
      final targetMonthStart =
          monthStart ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
      final targetMonthEnd =
          DateTime(targetMonthStart.year, targetMonthStart.month + 1, 0);
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final result = await supabase
          .from('expenses')
          .select('category, amount, date')
          .eq('user_id', user.id)
          .eq('crop_id', cropId)
          .gte('date', targetMonthStart.toIso8601String().split('T')[0])
          .lte('date', targetMonthEnd.toIso8601String().split('T')[0]);

      final weekTotals = <String, double>{};
      final weekCategories = <String, Map<String, double>>{};

      for (final item in result) {
        final category =
            _validateStringField(item['category'], 'category', 'other');
        final amount = _validateNumericField(item['amount'], 'amount', 0.0);
        final date = DateTime.parse(item['date']);

        // Calculate week start (Monday)
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final weekKey = weekStart.toIso8601String().split('T')[0];

        weekTotals[weekKey] = (weekTotals[weekKey] ?? 0.0) + amount;

        if (!weekCategories.containsKey(weekKey)) {
          weekCategories[weekKey] = {};
        }
        weekCategories[weekKey]![category] =
            (weekCategories[weekKey]![category] ?? 0.0) + amount;
      }

      return weekTotals.entries.map((entry) {
        final categoryBreakdown =
            weekCategories[entry.key]?.entries.map((catEntry) {
                  return ExpenseSummary(
                    category: catEntry.key,
                    totalAmount: catEntry.value,
                    count:
                        1, // We don't track individual counts in this aggregation
                  );
                }).toList() ??
                [];

        return WeeklyExpenseSummary(
          weekStart: entry.key,
          totalAmount: entry.value,
          categoryBreakdown: categoryBreakdown,
        );
      }).toList()
        ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
    } catch (e) {
      AppLogger.error('Failed to get monthly expenses: $e');
      return [];
    }
  }

  Future<double> getTotalExpenses({
    String? cropId,
    String? farmId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      var query =
          supabase.from('expenses').select('amount').eq('user_id', user.id);

      if (cropId != null) {
        query = query.eq('crop_id', cropId);
      }
      if (farmId != null) {
        query = query.eq('farm_id', farmId);
      }
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String().split('T')[0]);
      }

      final result = await query;
      double total = 0.0;

      for (final item in result) {
        total += _validateNumericField(item['amount'], 'amount', 0.0);
      }

      return total;
    } catch (e) {
      AppLogger.error('Failed to get total expenses: $e');
      return 0.0;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      await supabase
          .from('expenses')
          .delete()
          .eq('id', expenseId)
          .eq('user_id', user.id);

      AppLogger.info('Deleted expense: $expenseId');
    } catch (e) {
      AppLogger.error('Failed to delete expense: $e');
      rethrow;
    }
  }
}
