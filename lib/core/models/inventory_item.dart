enum PackStatus { good, low, critical, negative }

extension PackStatusX on PackStatus {
  static PackStatus fromString(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'CRITICAL':
        return PackStatus.critical;
      case 'LOW':
        return PackStatus.low;
      case 'NEGATIVE':
        return PackStatus.negative;
      default:
        return PackStatus.good;
    }
  }

  String get label {
    switch (this) {
      case PackStatus.good:
        return 'Good';
      case PackStatus.low:
        return 'Low';
      case PackStatus.critical:
        return 'Critical';
      case PackStatus.negative:
        return 'No stock';
    }
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final String unit;
  final String? cropId;
  final String? farmId;
  final bool isAutoTracked;

  final double openingQuantity;
  final double remainingQuantity;
  final double totalUsed;

  final double? pricePerUnit;
  final double? packSize;
  final double? costPerPack;
  final String packLabel;

  final double? totalPacks;
  final double? remainingPacks;

  final PackStatus status;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.cropId,
    required this.farmId,
    required this.isAutoTracked,
    required this.openingQuantity,
    required this.remainingQuantity,
    required this.totalUsed,
    required this.pricePerUnit,
    required this.packSize,
    required this.costPerPack,
    required this.packLabel,
    required this.totalPacks,
    required this.remainingPacks,
    required this.status,
  });

  factory InventoryItem.fromView(Map<String, dynamic> row) {
    double? n(dynamic v) => (v as num?)?.toDouble();
    return InventoryItem(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Unknown',
      category: (row['category'] as String?) ?? 'other',
      unit: (row['unit'] as String?) ?? '',
      cropId: row['crop_id'] as String?,
      farmId: row['farm_id'] as String?,
      isAutoTracked: row['is_auto_tracked'] == true,
      openingQuantity: n(row['opening_quantity']) ?? 0,
      remainingQuantity: n(row['expected_stock']) ?? 0,
      totalUsed: n(row['total_used']) ?? 0,
      pricePerUnit: n(row['price_per_unit']),
      packSize: n(row['pack_size']),
      costPerPack: n(row['cost_per_pack']),
      packLabel: (row['pack_label'] as String?) ?? 'pack',
      totalPacks: n(row['total_packs']),
      remainingPacks: n(row['remaining_packs']),
      status: PackStatusX.fromString(row['pack_status'] as String?),
    );
  }

  bool get hasPackTracking => packSize != null && packSize! > 0;

  /// "8 bags (200 kg)" when pack_size set, "200 kg" otherwise.
  String displayRemaining() {
    final qty = remainingQuantity.clamp(0, double.infinity);
    final qtyStr = '${_fmt(qty.toDouble())} $unit';
    if (!hasPackTracking || remainingPacks == null) return qtyStr;
    final packs = remainingPacks!.clamp(0, double.infinity).toDouble();
    return '${_fmt(packs)} ${_pluralLabel(packs)} ($qtyStr)';
  }

  String displayOpening() {
    final qtyStr = '${_fmt(openingQuantity)} $unit';
    if (!hasPackTracking || totalPacks == null) return qtyStr;
    return '${_fmt(totalPacks!)} ${_pluralLabel(totalPacks!)} ($qtyStr)';
  }

  String _pluralLabel(double count) {
    final base = packLabel;
    if (count == 1.0) return base;
    return base.endsWith('s') ? base : '${base}s';
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
