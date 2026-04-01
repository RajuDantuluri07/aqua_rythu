class SamplingLog {
  final int doc;
  final double abw; // ✅ primary field
  final DateTime date;
  final int totalPieces; // ✅ add this (used in UI)

  SamplingLog({
    required this.doc,
    required this.abw,
    required this.date,
    this.totalPieces = 0,
  });

  // ✅ Compatibility getter (for newer code)
  double get averageBodyWeight => abw;
}