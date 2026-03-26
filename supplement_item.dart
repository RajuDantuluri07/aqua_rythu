class SupplementItem {
  final String name;
  final double quantity;
  final String unit;
  final String type; // feed | water
  final String timing; // morning | evening | perFeed

  const SupplementItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.timing,
  });
}