import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/models/expense_model.dart';

void main() {
  group('Expense Model Tests', () {
    test('ExpenseCategory fromString should return correct category', () {
      expect(ExpenseCategory.fromString('labour'), ExpenseCategory.labour);
      expect(ExpenseCategory.fromString('electricity'),
          ExpenseCategory.electricity);
      expect(ExpenseCategory.fromString('diesel'), ExpenseCategory.diesel);
      expect(ExpenseCategory.fromString('sampling'), ExpenseCategory.sampling);
      expect(ExpenseCategory.fromString('other'), ExpenseCategory.other);
      expect(ExpenseCategory.fromString('invalid'), ExpenseCategory.other);
    });

    test('ExpenseCategory should have correct labels', () {
      expect(ExpenseCategory.labour.label, 'Labour');
      expect(ExpenseCategory.electricity.label, 'Electricity');
      expect(ExpenseCategory.diesel.label, 'Diesel/Oil');
      expect(ExpenseCategory.sampling.label, 'Sampling');
      expect(ExpenseCategory.other.label, 'Other');
    });

    test('Expense fromMap should create correct model', () {
      final map = {
        'id': '123',
        'user_id': 'user123',
        'farm_id': 'farm123',
        'crop_id': 'crop123',
        'category': 'labour',
        'amount': 500.0,
        'notes': 'Test expense',
        'date': '2024-01-15',
        'created_at': '2024-01-15T10:00:00Z',
      };

      final expense = Expense.fromMap(map);

      expect(expense.id, '123');
      expect(expense.userId, 'user123');
      expect(expense.farmId, 'farm123');
      expect(expense.cropId, 'crop123');
      expect(expense.category, ExpenseCategory.labour);
      expect(expense.amount, 500.0);
      expect(expense.notes, 'Test expense');
      expect(expense.date, DateTime.parse('2024-01-15'));
      expect(expense.createdAt, DateTime.parse('2024-01-15T10:00:00Z'));
    });

    test('Expense toMap should create correct map', () {
      final expense = Expense(
        id: '123',
        userId: 'user123',
        farmId: 'farm123',
        cropId: 'crop123',
        category: ExpenseCategory.labour,
        amount: 500.0,
        notes: 'Test expense',
        date: DateTime.parse('2024-01-15'),
        createdAt: DateTime.parse('2024-01-15T10:00:00Z'),
      );

      final map = expense.toMap();

      expect(map['id'], '123');
      expect(map['user_id'], 'user123');
      expect(map['farm_id'], 'farm123');
      expect(map['crop_id'], 'crop123');
      expect(map['category'], 'labour');
      expect(map['amount'], 500.0);
      expect(map['notes'], 'Test expense');
      expect(map['date'], '2024-01-15');
      expect(map['created_at'], '2024-01-15T10:00:00.000Z');
    });

    test('Expense copyWith should create correct copy', () {
      final original = Expense(
        userId: 'user123',
        farmId: 'farm123',
        cropId: 'crop123',
        category: ExpenseCategory.labour,
        amount: 500.0,
        date: DateTime.parse('2024-01-15'),
      );

      final copied = original.copyWith(
        amount: 600.0,
        notes: 'Updated notes',
      );

      expect(copied.userId, original.userId);
      expect(copied.farmId, original.farmId);
      expect(copied.cropId, original.cropId);
      expect(copied.category, original.category);
      expect(copied.amount, 600.0);
      expect(copied.notes, 'Updated notes');
      expect(copied.date, original.date);
    });
  });

  group('ExpenseSummary Model Tests', () {
    test('ExpenseSummary fromMap should create correct model', () {
      final map = {
        'category': 'labour',
        'total_amount': 1500.0,
        'count': 3,
      };

      final summary = ExpenseSummary.fromMap(map);

      expect(summary.category, 'labour');
      expect(summary.totalAmount, 1500.0);
      expect(summary.count, 3);
    });

    test('ExpenseSummary fromMap should handle missing data', () {
      final map = {
        'category': 'labour',
        // total_amount and count missing
      };

      final summary = ExpenseSummary.fromMap(map);

      expect(summary.category, 'labour');
      expect(summary.totalAmount, 0.0);
      expect(summary.count, 0);
    });
  });

  group('Expense Validation Tests', () {
    test('Expense should accept valid data', () {
      expect(
          () => Expense(
                userId: 'user123',
                farmId: 'farm123',
                cropId: 'crop123',
                category: ExpenseCategory.labour,
                amount: 100.0,
                date: DateTime.now(),
              ),
          returnsNormally);
    });

    test('Expense should handle zero amount', () {
      expect(
          () => Expense(
                userId: 'user123',
                farmId: 'farm123',
                cropId: 'crop123',
                category: ExpenseCategory.labour,
                amount: 0.0,
                date: DateTime.now(),
              ),
          returnsNormally);
    });

    test('Expense should handle negative amounts (validation in UI)', () {
      final expense = Expense(
        userId: 'user123',
        farmId: 'farm123',
        cropId: 'crop123',
        category: ExpenseCategory.labour,
        amount: -100.0,
        date: DateTime.now(),
      );
      expect(expense.amount, -100.0); // Model accepts it, UI validates
    });
  });

  group('Expense Category Enum Tests', () {
    test('All expense categories should have valid values', () {
      for (final category in ExpenseCategory.values) {
        expect(category.value.isNotEmpty, true);
        expect(category.label.isNotEmpty, true);
      }
    });

    test('ExpenseCategory values should be unique', () {
      final values = ExpenseCategory.values.map((e) => e.value).toList();
      final uniqueValues = values.toSet();
      expect(values.length, uniqueValues.length);
    });

    test('ExpenseCategory labels should be unique', () {
      final labels = ExpenseCategory.values.map((e) => e.label).toList();
      final uniqueLabels = labels.toSet();
      expect(labels.length, uniqueLabels.length);
    });
  });
}
