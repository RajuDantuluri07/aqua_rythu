import 'package:flutter/material.dart';

enum ExpenseCategory {
  feed('feed', 'Feed'),
  seed('seed', 'Seed / PL'),
  probiotic('probiotic', 'Probiotic'),
  mineral('mineral', 'Mineral'),
  medicine('medicine', 'Medicine'),
  labour('labour', 'Labour'),
  diesel('diesel', 'Diesel / Fuel'),
  electricity('electricity', 'Electricity'),
  waterTreatment('water_treatment', 'Water Treatment'),
  testing('sampling', 'Testing'),
  equipment('equipment', 'Equipment'),
  harvest('harvest', 'Harvest'),
  supplement('supplement', 'Supplement'), // legacy — kept for existing records
  other('other', 'Other');

  const ExpenseCategory(this.value, this.label);

  final String value;
  final String label;

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => ExpenseCategory.other,
    );
  }

  IconData get icon => switch (this) {
        ExpenseCategory.feed => Icons.grain,
        ExpenseCategory.seed => Icons.grass_rounded,
        ExpenseCategory.probiotic => Icons.science_outlined,
        ExpenseCategory.mineral => Icons.spa_outlined,
        ExpenseCategory.medicine => Icons.medication_outlined,
        ExpenseCategory.labour => Icons.people_outline,
        ExpenseCategory.diesel => Icons.local_gas_station,
        ExpenseCategory.electricity => Icons.bolt,
        ExpenseCategory.waterTreatment => Icons.water_drop_outlined,
        ExpenseCategory.testing => Icons.biotech_outlined,
        ExpenseCategory.equipment => Icons.build_outlined,
        ExpenseCategory.harvest => Icons.agriculture,
        ExpenseCategory.supplement => Icons.science_outlined,
        ExpenseCategory.other => Icons.more_horiz,
      };

  Color get color => switch (this) {
        ExpenseCategory.feed => const Color(0xFF4CAF50),
        ExpenseCategory.seed => const Color(0xFF8BC34A),
        ExpenseCategory.probiotic => const Color(0xFF00BCD4),
        ExpenseCategory.mineral => const Color(0xFF9C27B0),
        ExpenseCategory.medicine => const Color(0xFFE53935),
        ExpenseCategory.labour => const Color(0xFF2196F3),
        ExpenseCategory.diesel => const Color(0xFF795548),
        ExpenseCategory.electricity => const Color(0xFFFF9800),
        ExpenseCategory.waterTreatment => const Color(0xFF03A9F4),
        ExpenseCategory.testing => const Color(0xFF607D8B),
        ExpenseCategory.equipment => const Color(0xFF78909C),
        ExpenseCategory.harvest => const Color(0xFF43A047),
        ExpenseCategory.supplement => const Color(0xFF26C6DA),
        ExpenseCategory.other => const Color(0xFF9E9E9E),
      };
}

class Expense {
  final String? id;
  final String userId;
  final String farmId;
  final String? cropId; // nullable — farm-wide expenses have no crop cycle
  final String? pondId;
  final ExpenseCategory category;
  final double amount;
  final String? notes;
  final DateTime date;
  final DateTime? createdAt;

  Expense({
    this.id,
    required this.userId,
    required this.farmId,
    this.cropId,
    this.pondId,
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
      cropId: map['crop_id']?.toString(),
      pondId: map['pond_id']?.toString(),
      category: ExpenseCategory.fromString(map['category'] ?? 'other'),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes']?.toString(),
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : throw FormatException('expense date is null for id: ${map['id']}'),
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
      'pond_id': pondId,
      'category': category.value,
      'amount': amount,
      'notes': notes,
      'date': date.toIso8601String().split('T')[0],
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Expense copyWith({
    String? id,
    String? userId,
    String? farmId,
    String? cropId,
    String? pondId,
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
      pondId: pondId ?? this.pondId,
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
