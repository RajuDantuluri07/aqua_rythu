class SupplementScheduleLog {
  final String id;
  final String supplementScheduleId;
  final String? pondId;
  final String? supplementName;
  final DateTime appliedDate;
  final String? feedRound; // 'R1', 'R2', etc — null for water treatments
  final String status; // 'pending' | 'applied' | 'skipped'
  final String? remarks;
  final List<Map<String, dynamic>> appliedItems; // JSON dose breakdown
  final double? inputValue; // feed kg or pond area
  final String? inputUnit; // 'kg' or 'acre'
  final String? createdBy;
  final DateTime createdAt;

  const SupplementScheduleLog({
    required this.id,
    required this.supplementScheduleId,
    this.pondId,
    this.supplementName,
    required this.appliedDate,
    this.feedRound,
    this.status = 'applied',
    this.remarks,
    this.appliedItems = const [],
    this.inputValue,
    this.inputUnit,
    this.createdBy,
    required this.createdAt,
  });

  SupplementScheduleLog copyWith({
    String? id,
    String? supplementScheduleId,
    String? pondId,
    String? supplementName,
    DateTime? appliedDate,
    String? feedRound,
    String? status,
    String? remarks,
    List<Map<String, dynamic>>? appliedItems,
    double? inputValue,
    String? inputUnit,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return SupplementScheduleLog(
      id: id ?? this.id,
      supplementScheduleId: supplementScheduleId ?? this.supplementScheduleId,
      pondId: pondId ?? this.pondId,
      supplementName: supplementName ?? this.supplementName,
      appliedDate: appliedDate ?? this.appliedDate,
      feedRound: feedRound ?? this.feedRound,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      appliedItems: appliedItems ?? this.appliedItems,
      inputValue: inputValue ?? this.inputValue,
      inputUnit: inputUnit ?? this.inputUnit,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SupplementScheduleLog.fromJson(Map<String, dynamic> json) {
    final rawItems = json['applied_items'];
    final itemsList = rawItems is List
        ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    return SupplementScheduleLog(
      id: json['id'] as String,
      supplementScheduleId: json['supplement_schedule_id'] as String,
      pondId: json['pond_id'] as String?,
      supplementName: json['supplement_name'] as String?,
      appliedDate: DateTime.parse(json['applied_date'] as String),
      feedRound: json['feed_round'] as String?,
      status: json['status'] as String? ?? 'applied',
      remarks: json['remarks'] as String?,
      appliedItems: itemsList,
      inputValue: (json['input_value'] as num?)?.toDouble(),
      inputUnit: json['input_unit'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplement_schedule_id': supplementScheduleId,
        'pond_id': pondId,
        'supplement_name': supplementName,
        'applied_date': appliedDate.toIso8601String().split('T')[0],
        'feed_round': feedRound,
        'status': status,
        'remarks': remarks,
        'applied_items': appliedItems,
        'input_value': inputValue,
        'input_unit': inputUnit,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() =>
      'SupplementScheduleLog(id: $id, pond: $pondId, supplement: $supplementName, status: $status)';
}
