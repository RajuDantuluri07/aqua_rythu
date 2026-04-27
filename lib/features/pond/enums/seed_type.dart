enum SeedType {
  hatcherySmall,
  nurseryBig,
}

extension SeedTypeX on SeedType {
  String get displayName {
    switch (this) {
      case SeedType.hatcherySmall:
        return 'Hatchery Seed';
      case SeedType.nurseryBig:
        return 'Nursery Seed';
    }
  }

  String get description {
    switch (this) {
      case SeedType.hatcherySmall:
        return 'Small shrimp (PL size ≤ 15mm)';
      case SeedType.nurseryBig:
        return 'Big shrimp (PL size > 15mm)';
    }
  }

  String get dbValue {
    switch (this) {
      case SeedType.hatcherySmall:
        return 'hatchery';
      case SeedType.nurseryBig:
        return 'nursery';
    }
  }

  static SeedType fromDb(String? value) {
    switch (value) {
      case 'nursery':
        return SeedType.nurseryBig;
      default:
        return SeedType.hatcherySmall;
    }
  }

  /// Auto-detect seed type from PL size.
  /// PL ≤ 15mm → hatchery (small); PL > 15mm → nursery (big).
  static SeedType fromPlSize(int plSize) {
    return plSize <= 15 ? SeedType.hatcherySmall : SeedType.nurseryBig;
  }
}
