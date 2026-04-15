import 'package:flutter/material.dart';

enum FeedSource { doc, biomass }

class FeedResult {
  final double finalFeed;
  final FeedSource source;

  final double docFeed;
  final double? biomassFeed;

  final double? fcrFactor;
  final double? trayFactor;
  final double? growthFactor;

  final String explanation;
  final double confidenceScore;
  
  /// Actionable recommendations for the farmer
  final List<String> recommendations;

  FeedResult({
    required this.finalFeed,
    required this.source,
    required this.docFeed,
    this.biomassFeed,
    this.fcrFactor,
    this.trayFactor,
    this.growthFactor,
    required this.explanation,
    required this.confidenceScore,
    this.recommendations = const [],
  });
}

