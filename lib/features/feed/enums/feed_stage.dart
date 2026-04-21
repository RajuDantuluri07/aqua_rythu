// Feed Stage — sampling-awareness gate for the feed correction pipeline.
//
// Unlike FeedMode (which is DOC-based only), FeedStage considers whether
// the pond has ABW sampling data available. This allows the pipeline to
// progressively unlock correction factors as data matures.
//
// Resolver: FeedStageResolver.resolve(doc, hasSampling)

/// Feed stage describing how much correction data is available.
///
/// [blind]        DOC < 30 or no ABW sampling — no growth/FCR corrections.
/// [transitional] Has sampling, DOC 30–39 — growth corrections active, FCR off.
/// [intelligent]  Has sampling, DOC ≥ 40 — all corrections including FCR.
enum FeedStage { blind, transitional, intelligent }

class FeedStageResolver {
  /// Resolve the current feed stage from [doc] and [hasSampling].
  /// Fix #4: blind stage covers through DOC 30 (smart phase is DOC ≥ 31).
  static FeedStage resolve({required int doc, required bool hasSampling}) {
    if (!hasSampling || doc <= 30) return FeedStage.blind;
    if (doc < 41) return FeedStage.transitional;
    return FeedStage.intelligent;
  }
}
