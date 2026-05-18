enum CropStatus { active, partialHarvest, completed, archived }

extension CropStatusX on CropStatus {
  String get dbValue => switch (this) {
        CropStatus.active => 'ACTIVE',
        CropStatus.partialHarvest => 'PARTIAL_HARVEST',
        CropStatus.completed => 'COMPLETED',
        CropStatus.archived => 'ARCHIVED',
      };

  bool get isOperational =>
      this == CropStatus.active || this == CropStatus.partialHarvest;

  static CropStatus fromDb(String? value) =>
      switch (value?.toUpperCase()) {
        'PARTIAL_HARVEST' => CropStatus.partialHarvest,
        'COMPLETED' => CropStatus.completed,
        'ARCHIVED' => CropStatus.archived,
        _ => CropStatus.active,
      };
}

enum PondLifecycleStatus { prep, stocked, active, partialHarvest, harvested }

extension PondLifecycleStatusX on PondLifecycleStatus {
  String get dbValue => switch (this) {
        PondLifecycleStatus.prep => 'PREP',
        PondLifecycleStatus.stocked => 'STOCKED',
        PondLifecycleStatus.active => 'ACTIVE',
        PondLifecycleStatus.partialHarvest => 'PARTIAL_HARVEST',
        PondLifecycleStatus.harvested => 'HARVESTED',
      };

  bool get isOperational =>
      this == PondLifecycleStatus.active ||
      this == PondLifecycleStatus.stocked ||
      this == PondLifecycleStatus.partialHarvest;

  static PondLifecycleStatus fromDb(String? value) =>
      switch (value?.toUpperCase()) {
        'PREP' => PondLifecycleStatus.prep,
        'STOCKED' => PondLifecycleStatus.stocked,
        'PARTIAL_HARVEST' => PondLifecycleStatus.partialHarvest,
        'HARVESTED' => PondLifecycleStatus.harvested,
        _ => PondLifecycleStatus.active,
      };
}

enum HarvestStatus { notStarted, partial, completed }

extension HarvestStatusX on HarvestStatus {
  String get dbValue => switch (this) {
        HarvestStatus.notStarted => 'NOT_STARTED',
        HarvestStatus.partial => 'PARTIAL',
        HarvestStatus.completed => 'COMPLETED',
      };

  static HarvestStatus fromDb(String? value) =>
      switch (value?.toUpperCase()) {
        'PARTIAL' => HarvestStatus.partial,
        'COMPLETED' => HarvestStatus.completed,
        _ => HarvestStatus.notStarted,
      };
}

class CropCycle {
  final String id;
  final String farmId;
  final String name;
  final String? species;
  final DateTime? stockingDate;
  final DateTime? expectedHarvestDate;
  final CropStatus status;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? completedAt;

  const CropCycle({
    required this.id,
    required this.farmId,
    required this.name,
    this.species,
    this.stockingDate,
    this.expectedHarvestDate,
    required this.status,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.completedAt,
  });

  factory CropCycle.fromMap(Map<String, dynamic> map) {
    return CropCycle(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      name: map['name'] as String? ?? 'Unnamed Cycle',
      species: map['species'] as String?,
      stockingDate: map['stocking_date'] != null
          ? DateTime.tryParse(map['stocking_date'] as String)
          : null,
      expectedHarvestDate: map['expected_harvest_date'] != null
          ? DateTime.tryParse(map['expected_harvest_date'] as String)
          : null,
      status: CropStatusX.fromDb(map['status'] as String?),
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'farm_id': farmId,
        'name': name,
        if (species != null) 'species': species,
        if (stockingDate != null)
          'stocking_date': stockingDate!.toIso8601String().split('T')[0],
        if (expectedHarvestDate != null)
          'expected_harvest_date':
              expectedHarvestDate!.toIso8601String().split('T')[0],
        'status': status.dbValue,
        if (notes != null) 'notes': notes,
        if (createdBy != null) 'created_by': createdBy,
      };

  CropCycle copyWith({
    String? id,
    String? farmId,
    String? name,
    String? species,
    DateTime? stockingDate,
    DateTime? expectedHarvestDate,
    CropStatus? status,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? completedAt,
  }) =>
      CropCycle(
        id: id ?? this.id,
        farmId: farmId ?? this.farmId,
        name: name ?? this.name,
        species: species ?? this.species,
        stockingDate: stockingDate ?? this.stockingDate,
        expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}
