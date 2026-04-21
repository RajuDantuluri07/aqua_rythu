/// DTO for remote feed configuration.
/// Allows backend-driven tuning of feed calculation parameters.
class FeedConfigDto {
  final double hatcheryStart;
  final double hatcheryIncrement;
  final double nurseryStart;
  final double nurseryIncrement;
  final int maxDoc;

  const FeedConfigDto({
    required this.hatcheryStart,
    required this.hatcheryIncrement,
    required this.nurseryStart,
    required this.nurseryIncrement,
    required this.maxDoc,
  });

  /// Creates a copy with updated values.
  FeedConfigDto copyWith({
    double? hatcheryStart,
    double? hatcheryIncrement,
    double? nurseryStart,
    double? nurseryIncrement,
    int? maxDoc,
  }) {
    return FeedConfigDto(
      hatcheryStart: hatcheryStart ?? this.hatcheryStart,
      hatcheryIncrement: hatcheryIncrement ?? this.hatcheryIncrement,
      nurseryStart: nurseryStart ?? this.nurseryStart,
      nurseryIncrement: nurseryIncrement ?? this.nurseryIncrement,
      maxDoc: maxDoc ?? this.maxDoc,
    );
  }
}