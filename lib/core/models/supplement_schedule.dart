class SupplementSchedule {
  final String id;
  final String pondId;
  final String? farmId;
  final String? productId;
  final String? productName;
  final String? categoryName;
  final String? categoryId;
  final String applicationType; // 'feed_mix' | 'water_mix'
  final DateTime startDate;
  final DateTime endDate;
  final List<String> selectedFeedRounds;
  final String? notes;
  final String status; // 'active' | 'paused' | 'completed'
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Water mix only: "HH:mm" (24h) — used to position the card in the feed timeline
  final String? scheduledTime;
  /// Water mix only: repeat interval in days (null = one-time, 7/10/15/30 = recurring)
  final int? frequencyDays;

  const SupplementSchedule({
    required this.id,
    required this.pondId,
    this.farmId,
    this.productId,
    this.productName,
    this.categoryName,
    this.categoryId,
    required this.applicationType,
    required this.startDate,
    required this.endDate,
    this.selectedFeedRounds = const [],
    this.notes,
    this.status = 'active',
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.scheduledTime,
    this.frequencyDays,
  });

  bool get isActive => status == 'active';

  bool isActiveOnDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);

    if (dateOnly.isBefore(startOnly) || dateOnly.isAfter(endOnly) || !isActive) {
      return false;
    }

    // Water mix with repeat: only active on days that are exact multiples of
    // frequencyDays from the start date (e.g., every 7 days).
    if (applicationType == 'water_mix' &&
        frequencyDays != null &&
        frequencyDays! > 0) {
      final diff = dateOnly.difference(startOnly).inDays;
      return diff % frequencyDays! == 0;
    }

    return true;
  }

  SupplementSchedule copyWith({
    String? id,
    String? pondId,
    String? farmId,
    String? productId,
    String? productName,
    String? categoryName,
    String? categoryId,
    String? applicationType,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? selectedFeedRounds,
    String? notes,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? scheduledTime,
    int? frequencyDays,
  }) {
    return SupplementSchedule(
      id: id ?? this.id,
      pondId: pondId ?? this.pondId,
      farmId: farmId ?? this.farmId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
      applicationType: applicationType ?? this.applicationType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      selectedFeedRounds: selectedFeedRounds ?? this.selectedFeedRounds,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      frequencyDays: frequencyDays ?? this.frequencyDays,
    );
  }

  factory SupplementSchedule.fromJson(Map<String, dynamic> json) {
    return SupplementSchedule(
      id: json['id'] as String,
      pondId: json['pond_id'] as String,
      farmId: json['farm_id'] as String?,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String?,
      categoryName: json['category_name'] as String?,
      categoryId: json['category_id'] as String?,
      applicationType: json['application_type'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      selectedFeedRounds:
          List<String>.from(json['selected_feed_rounds'] as List? ?? []),
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'active',
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      scheduledTime: json['scheduled_time'] as String?,
      frequencyDays: json['frequency_days'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pond_id': pondId,
        'farm_id': farmId,
        'product_id': productId,
        'product_name': productName,
        'category_name': categoryName,
        'category_id': categoryId,
        'application_type': applicationType,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'selected_feed_rounds': selectedFeedRounds,
        'notes': notes,
        'status': status,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'scheduled_time': scheduledTime,
        'frequency_days': frequencyDays,
      };

  @override
  String toString() =>
      'SupplementSchedule(id: $id, pond: $pondId, category: $categoryName, type: $applicationType, status: $status)';
}
