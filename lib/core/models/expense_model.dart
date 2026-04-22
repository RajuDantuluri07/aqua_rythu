enum ExpenseCategory {
  feed('feed', 'Feed'),
  labour('labour', 'Labour'),
  electricity('electricity', 'Electricity'),
  diesel('diesel', 'Diesel/Oil'),
  sampling('sampling', 'Sampling'),
  other('other', 'Other');

  const ExpenseCategory(this.value, this.label);

  final String value;
  final String label;

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class Expense {
  final String? id;
  final String userId;
  final String farmId;
  final String cropId;
  final ExpenseCategory category;
  final double amount;
  final String? notes;
  final DateTime date;
  final DateTime? createdAt;

  Expense({
    this.id,
    required this.userId,
    required this.farmId,
    required this.cropId,
    required this.category,
    required this.amount,
    this.notes,
    required this.date,
    this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      farmId: map['farm_id']?.toString() ?? '',
      cropId: map['crop_id']?.toString() ?? '',
      category: ExpenseCategory.fromString(map['category'] ?? 'other'),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes']?.toString(),
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'farm_id': farmId,
      'crop_id': cropId,
      'category': category.value,
      'amount': amount,
      'notes': notes,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Expense copyWith({
    String? id,
    String? userId,
    String? farmId,
    String? cropId,
    ExpenseCategory? category,
    double? amount,
    String? notes,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      farmId: farmId ?? this.farmId,
      cropId: cropId ?? this.cropId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ExpenseSummary {
  final String category;
  final double totalAmount;
  final int count;

  ExpenseSummary({
    required this.category,
    required this.totalAmount,
    required this.count,
  });

  factory ExpenseSummary.fromMap(Map<String, dynamic> map) {
    return ExpenseSummary(
      category: map['category'] ?? 'Unknown',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class WeeklyExpenseSummary {
  final String weekStart;
  final double totalAmount;
  final List<ExpenseSummary> categoryBreakdown;

  WeeklyExpenseSummary({
    required this.weekStart,
    required this.totalAmount,
    required this.categoryBreakdown,
  });
}
