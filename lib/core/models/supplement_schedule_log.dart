class SupplementScheduleLog {
  final String id;
  final String supplementScheduleId;
  final DateTime appliedDate;
  final String? feedRound; // 'R1', 'R2', etc — null for water treatments
  final String status; // 'pending' | 'applied' | 'skipped'
  final String? remarks;
  final DateTime createdAt;

  const SupplementScheduleLog({
    required this.id,
    required this.supplementScheduleId,
    required this.appliedDate,
    this.feedRound,
    this.status = 'pending',
    this.remarks,
    required this.createdAt,
  });

  SupplementScheduleLog copyWith({
    String? id,
    String? supplementScheduleId,
    DateTime? appliedDate,
    String? feedRound,
    String? status,
    String? remarks,
    DateTime? createdAt,
  }) {
    return SupplementScheduleLog(
      id: id ?? this.id,
      supplementScheduleId: supplementScheduleId ?? this.supplementScheduleId,
      appliedDate: appliedDate ?? this.appliedDate,
      feedRound: feedRound ?? this.feedRound,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SupplementScheduleLog.fromJson(Map<String, dynamic> json) {
    return SupplementScheduleLog(
      id: json['id'] as String,
      supplementScheduleId: json['supplement_schedule_id'] as String,
      appliedDate: DateTime.parse(json['applied_date'] as String),
      feedRound: json['feed_round'] as String?,
      status: json['status'] as String? ?? 'pending',
      remarks: json['remarks'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplement_schedule_id': supplementScheduleId,
        'applied_date': appliedDate.toIso8601String().split('T')[0],
        'feed_round': feedRound,
        'status': status,
        'remarks': remarks,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() =>
      'SupplementScheduleLog(id: $id, schedule: $supplementScheduleId, status: $status)';
}
