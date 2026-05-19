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

  // ── Water mix scheduling ───────────────────────────────────────────────────
  /// "HH:mm" (24h) — positions the card in the feed timeline
  final String? scheduledTime;
  /// Repeat interval in days. null / 0 = one-time. 7/10/15/30 = recurring.
  final int? frequencyDays;

  // ── Lifecycle management (T2) ──────────────────────────────────────────────
  /// True when the farmer has paused the schedule (hides from timeline + logs).
  final bool isPaused;
  /// Farmer-set stop date for recurring schedules. null = run indefinitely.
  final DateTime? stopDate;

  // ── Inventory consumption hook (T3) ────────────────────────────────────────
  /// Per-application quantity (e.g. 5 kg, 2 L). Optional metadata for future
  /// inventory deduction engine.
  final double? quantity;
  final String? unit; // 'g' | 'kg' | 'ml' | 'L'

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
    this.isPaused = false,
    this.stopDate,
    this.quantity,
    this.unit,
  });

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isActive => status == 'active';

  bool get isRecurring =>
      applicationType == 'water_mix' &&
      frequencyDays != null &&
      frequencyDays! > 0;

  // ── T5: Recurrence label ───────────────────────────────────────────────────

  /// Human-readable recurrence description for cards, notifications, previews.
  String recurrenceLabel() {
    if (!isRecurring) return 'Only This Time';
    switch (frequencyDays) {
      case 7:
        return 'Every 7 Days';
      case 10:
        return 'Every 10 Days';
      case 15:
        return 'Every 15 Days';
      case 30:
        return 'Every 30 Days';
      default:
        return 'Every $frequencyDays Days';
    }
  }

  // ── Core active-date check ─────────────────────────────────────────────────

  bool isActiveOnDate(DateTime date) {
    if (isPaused || !isActive) return false;

    final d = _dateOnly(date);
    final start = _dateOnly(startDate);

    if (d.isBefore(start)) return false;

    // Effective end boundary: stopDate > endDate for recurring schedules.
    final effectiveEnd = stopDate != null ? _dateOnly(stopDate!) : _dateOnly(endDate);
    if (d.isAfter(effectiveEnd)) return false;

    // Recurring water mix: only valid on exact cadence days.
    if (isRecurring) {
      return d.difference(start).inDays % frequencyDays! == 0;
    }

    return true;
  }

  // ── T1: Next occurrence engine ─────────────────────────────────────────────

  /// Returns the first occurrence date >= [afterDate], or null if the schedule
  /// has ended or is paused.
  ///
  /// One-time: returns [startDate] if [afterDate] <= [startDate], else null.
  /// Recurring: returns [startDate + N × frequencyDays] for smallest N >= 0
  ///   such that the result is >= [afterDate] and within the effective stop date.
  DateTime? getNextOccurrence(DateTime afterDate) {
    if (isPaused || !isActive) return null;

    final after = _dateOnly(afterDate);
    final start = _dateOnly(startDate);

    // One-time schedule
    if (!isRecurring) {
      if (!after.isAfter(start)) return start;
      return null;
    }

    // Recurring: find first candidate >= after
    DateTime candidate;
    if (!after.isAfter(start)) {
      candidate = start;
    } else {
      final diff = after.difference(start).inDays;
      // Ceiling division: smallest N such that N * freq >= diff
      final n = (diff + frequencyDays! - 1) ~/ frequencyDays!;
      candidate = start.add(Duration(days: n * frequencyDays!));
    }

    // Check effective stop boundary
    final effectiveEnd = stopDate != null ? _dateOnly(stopDate!) : _dateOnly(endDate);
    if (candidate.isAfter(effectiveEnd)) return null;

    return candidate;
  }

  /// Returns up to [limit] upcoming occurrence dates starting from [fromDate].
  /// Used by reminder engine, dashboard previews, and upcoming-dates UI.
  List<DateTime> getUpcomingOccurrences({
    required DateTime fromDate,
    int limit = 3,
  }) {
    final occurrences = <DateTime>[];
    DateTime cursor = _dateOnly(fromDate);

    while (occurrences.length < limit) {
      final next = getNextOccurrence(cursor);
      if (next == null) break;
      occurrences.add(next);
      // Advance past this date to find the next one
      cursor = next.add(const Duration(days: 1));
    }

    return occurrences;
  }

  // ── copyWith ───────────────────────────────────────────────────────────────

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
    bool? isPaused,
    DateTime? stopDate,
    double? quantity,
    String? unit,
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
      isPaused: isPaused ?? this.isPaused,
      stopDate: stopDate ?? this.stopDate,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }

  // ── JSON ───────────────────────────────────────────────────────────────────

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
      isPaused: json['is_paused'] as bool? ?? false,
      stopDate: json['stop_date'] != null
          ? DateTime.parse(json['stop_date'] as String)
          : null,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
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
        'is_paused': isPaused,
        'stop_date': stopDate?.toIso8601String().split('T')[0],
        'quantity': quantity,
        'unit': unit,
      };

  @override
  String toString() =>
      'SupplementSchedule(id: $id, pond: $pondId, type: $applicationType, '
      'paused: $isPaused, freq: $frequencyDays, status: $status)';

  // ── Private helpers ────────────────────────────────────────────────────────

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
