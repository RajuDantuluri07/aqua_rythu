/// Farmer feedback service for adaptive learning
/// Collects and processes farmer feedback to improve insight quality
library;

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class FarmerFeedbackService {
  static const String _feedbackKey = 'farmer_insight_feedback';
  static const String _feedbackStatsKey = 'insight_feedback_stats';
  
  static FarmerFeedbackService? _instance;
  static FarmerFeedbackService get instance => _instance ??= FarmerFeedbackService._();
  
  FarmerFeedbackService._();

  /// Record farmer feedback for an insight
  Future<void> recordFeedback({
    required String insightId,
    required bool isUseful,
    String? comment,
    String? pondId,
  }) async {
    try {
      final feedback = FarmerFeedback(
        insightId: insightId,
        isUseful: isUseful,
        timestamp: DateTime.now(),
        comment: comment,
        pondId: pondId,
      );

      // Save locally
      await _saveFeedbackLocally(feedback);

      // Sync to server if available
      await _syncFeedbackToServer(feedback);

      // Update insight statistics
      await _updateInsightStats(insightId, isUseful);

      AppLogger.info('Farmer feedback recorded: $insightId - useful: $isUseful');
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to record farmer feedback', e, stackTrace);
    }
  }

  /// Get feedback history for an insight
  Future<List<FarmerFeedback>> getFeedbackHistory(String insightId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final feedbackJson = prefs.getString(_feedbackKey) ?? '[]';
      final allFeedback = (jsonDecode(feedbackJson) as List)
          .map((e) => FarmerFeedback.fromJson(e))
          .toList();

      return allFeedback.where((f) => f.insightId == insightId).toList();
      
    } catch (e) {
      AppLogger.error('Failed to get feedback history', e);
      return [];
    }
  }

  /// Get overall feedback statistics
  Future<InsightFeedbackStats> getFeedbackStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_feedbackStatsKey);
      
      if (statsJson != null) {
        return InsightFeedbackStats.fromJson(jsonDecode(statsJson));
      }
      
      return InsightFeedbackStats.empty();
      
    } catch (e) {
      AppLogger.error('Failed to get feedback stats', e);
      return InsightFeedbackStats.empty();
    }
  }

  /// Calculate insight quality score based on feedback
  Future<double> getInsightQualityScore(String insightId) async {
    try {
      final feedback = await getFeedbackHistory(insightId);
      
      if (feedback.isEmpty) return 0.5; // Neutral score for no feedback

      // Apply time decay - recent feedback weighs more
      double weightedScore = 0;
      double totalWeight = 0;
      
      for (final f in feedback) {
        final daysSince = DateTime.now().difference(f.timestamp).inDays;
        final weight = 1.0 / (1.0 + daysSince * 0.1); // Decay factor
        
        weightedScore += (f.isUseful ? 1.0 : 0.0) * weight;
        totalWeight += weight;
      }
      
      return totalWeight > 0 ? weightedScore / totalWeight : 0.5;
      
    } catch (e) {
      AppLogger.error('Failed to calculate insight quality score', e);
      return 0.5;
    }
  }

  /// Get feedback patterns for learning
  Future<FeedbackPatterns> analyzeFeedbackPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final feedbackJson = prefs.getString(_feedbackKey) ?? '[]';
      final allFeedback = (jsonDecode(feedbackJson) as List)
          .map((e) => FarmerFeedback.fromJson(e))
          .toList();

      final patterns = FeedbackPatterns();
      
      // Analyze by insight type
      for (final feedback in allFeedback) {
        patterns.recordFeedback(feedback);
      }

      return patterns;
      
    } catch (e) {
      AppLogger.error('Failed to analyze feedback patterns', e);
      return FeedbackPatterns();
    }
  }

  /// Generate adaptive recommendations based on feedback
  Future<List<AdaptiveRecommendation>> generateAdaptiveRecommendations() async {
    try {
      final patterns = await analyzeFeedbackPatterns();
      final recommendations = <AdaptiveRecommendation>[];

      // Find insight types with low usefulness
      final lowPerformingTypes = patterns.getLowPerformingTypes();
      
      for (final type in lowPerformingTypes) {
        recommendations.add(AdaptiveRecommendation(
          type: RecommendationType.improveInsight,
          insightType: type,
          description: 'Insights of type $type have low farmer feedback. Consider improving relevance or accuracy.',
          priority: RecommendationPriority.medium,
          suggestedActions: [
            'Review insight generation logic',
            'Add more context-specific data',
            'Improve confidence scoring',
            'Enhance actionability',
          ],
        ));
      }

      // Find high-performing patterns
      final highPerformingTypes = patterns.getHighPerformingTypes();
      
      for (final type in highPerformingTypes) {
        recommendations.add(AdaptiveRecommendation(
          type: RecommendationType.expandInsight,
          insightType: type,
          description: 'Insights of type $type perform well. Consider expanding similar insights.',
          priority: RecommendationPriority.low,
          suggestedActions: [
            'Generate more insights of this type',
            'Apply similar logic to other areas',
            'Increase confidence threshold',
          ],
        ));
      }

      return recommendations;
      
    } catch (e) {
      AppLogger.error('Failed to generate adaptive recommendations', e);
      return [];
    }
  }

  Future<void> _saveFeedbackLocally(FarmerFeedback feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final feedbackJson = prefs.getString(_feedbackKey) ?? '[]';
    final allFeedback = (jsonDecode(feedbackJson) as List)
        .map((e) => FarmerFeedback.fromJson(e))
        .toList();

    allFeedback.add(feedback);

    // Keep only last 1000 feedback entries
    if (allFeedback.length > 1000) {
      allFeedback.removeRange(0, allFeedback.length - 1000);
    }

    await prefs.setString(_feedbackKey, jsonEncode(allFeedback.map((f) => f.toJson()).toList()));
  }

  Future<void> _syncFeedbackToServer(FarmerFeedback feedback) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('farmer_feedback').insert({
        'insight_id': feedback.insightId,
        'is_useful': feedback.isUseful,
        'timestamp': feedback.timestamp.toIso8601String(),
        'comment': feedback.comment,
        'pond_id': feedback.pondId,
        'created_at': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      AppLogger.warn('Failed to sync feedback to server (will retry later): $e');
      // Don't throw - local storage is sufficient
    }
  }

  Future<void> _updateInsightStats(String insightId, bool isUseful) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_feedbackStatsKey);
      
      InsightFeedbackStats stats;
      if (statsJson != null) {
        stats = InsightFeedbackStats.fromJson(jsonDecode(statsJson));
      } else {
        stats = InsightFeedbackStats.empty();
      }

      stats.recordFeedback(insightId, isUseful);
      
      await prefs.setString(_feedbackStatsKey, jsonEncode(stats.toJson()));
      
    } catch (e) {
      AppLogger.error('Failed to update insight stats', e);
    }
  }

  /// Get feedback for insight type performance
  Future<Map<String, double>> getInsightTypePerformance() async {
    try {
      final patterns = await analyzeFeedbackPatterns();
      return patterns.getTypePerformance();
      
    } catch (e) {
      AppLogger.error('Failed to get insight type performance', e);
      return {};
    }
  }

  /// Clear old feedback data
  Future<void> cleanupOldData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final feedbackJson = prefs.getString(_feedbackKey) ?? '[]';
      final allFeedback = (jsonDecode(feedbackJson) as List)
          .map((e) => FarmerFeedback.fromJson(e))
          .toList();

      // Remove feedback older than 90 days
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final recentFeedback = allFeedback.where((f) => f.timestamp.isAfter(cutoff)).toList();

      await prefs.setString(_feedbackKey, jsonEncode(recentFeedback.map((f) => f.toJson()).toList()));
      
      AppLogger.info('Cleaned up old feedback data: removed ${allFeedback.length - recentFeedback.length} entries');
      
    } catch (e) {
      AppLogger.error('Failed to cleanup old data', e);
    }
  }
}

class FarmerFeedback {
  final String insightId;
  final bool isUseful;
  final DateTime timestamp;
  final String? comment;
  final String? pondId;

  const FarmerFeedback({
    required this.insightId,
    required this.isUseful,
    required this.timestamp,
    this.comment,
    this.pondId,
  });

  factory FarmerFeedback.fromJson(Map<String, dynamic> json) {
    return FarmerFeedback(
      insightId: json['insightId'] as String,
      isUseful: json['isUseful'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      comment: json['comment'] as String?,
      pondId: json['pondId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'insightId': insightId,
      'isUseful': isUseful,
      'timestamp': timestamp.toIso8601String(),
      'comment': comment,
      'pondId': pondId,
    };
  }
}

class InsightFeedbackStats {
  final Map<String, int> totalFeedback;
  final Map<String, int> usefulFeedback;
  final DateTime lastUpdated;

  const InsightFeedbackStats({
    required this.totalFeedback,
    required this.usefulFeedback,
    required this.lastUpdated,
  });

  factory InsightFeedbackStats.empty() {
    return InsightFeedbackStats(
      totalFeedback: {},
      usefulFeedback: {},
      lastUpdated: DateTime.now(),
    );
  }

  factory InsightFeedbackStats.fromJson(Map<String, dynamic> json) {
    return InsightFeedbackStats(
      totalFeedback: Map<String, int>.from(json['totalFeedback'] ?? {}),
      usefulFeedback: Map<String, int>.from(json['usefulFeedback'] ?? {}),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  void recordFeedback(String insightId, bool isUseful) {
    totalFeedback[insightId] = (totalFeedback[insightId] ?? 0) + 1;
    if (isUseful) {
      usefulFeedback[insightId] = (usefulFeedback[insightId] ?? 0) + 1;
    }
  }

  double getUsefulnessScore(String insightId) {
    final total = totalFeedback[insightId] ?? 0;
    final useful = usefulFeedback[insightId] ?? 0;
    return total > 0 ? useful / total : 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'totalFeedback': totalFeedback,
      'usefulFeedback': usefulFeedback,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class FeedbackPatterns {
  final Map<String, List<FarmerFeedback>> feedbackByType = {};
  final Map<String, List<FarmerFeedback>> feedbackByPond = {};

  void recordFeedback(FarmerFeedback feedback) {
    // This would be enhanced with actual insight type extraction
    // For now, we'll use the insight ID prefix as type
    final type = _extractInsightType(feedback.insightId);
    feedbackByType.putIfAbsent(type, () => []).add(feedback);

    if (feedback.pondId != null) {
      feedbackByPond.putIfAbsent(feedback.pondId!, () => []).add(feedback);
    }
  }

  String _extractInsightType(String insightId) {
    if (insightId.startsWith('growth_')) return 'growth';
    if (insightId.startsWith('feed_')) return 'feed';
    if (insightId.startsWith('sampling_')) return 'sampling';
    if (insightId.startsWith('harvest_')) return 'harvest';
    return 'other';
  }

  List<String> getLowPerformingTypes() {
    final results = <String>[];
    
    for (final entry in feedbackByType.entries) {
      final type = entry.key;
      final feedback = entry.value;
      
      if (feedback.length >= 5) { // Only consider types with sufficient data
        final usefulCount = feedback.where((f) => f.isUseful).length;
        final score = usefulCount / feedback.length;
        
        if (score < 0.4) { // Less than 40% useful
          results.add(type);
        }
      }
    }
    
    return results;
  }

  List<String> getHighPerformingTypes() {
    final results = <String>[];
    
    for (final entry in feedbackByType.entries) {
      final type = entry.key;
      final feedback = entry.value;
      
      if (feedback.length >= 5) { // Only consider types with sufficient data
        final usefulCount = feedback.where((f) => f.isUseful).length;
        final score = usefulCount / feedback.length;
        
        if (score > 0.8) { // More than 80% useful
          results.add(type);
        }
      }
    }
    
    return results;
  }

  Map<String, double> getTypePerformance() {
    final performance = <String, double>{};
    
    for (final entry in feedbackByType.entries) {
      final type = entry.key;
      final feedback = entry.value;
      
      if (feedback.isNotEmpty) {
        final usefulCount = feedback.where((f) => f.isUseful).length;
        performance[type] = usefulCount / feedback.length;
      }
    }
    
    return performance;
  }
}

class AdaptiveRecommendation {
  final RecommendationType type;
  final String? insightType;
  final String description;
  final RecommendationPriority priority;
  final List<String> suggestedActions;

  const AdaptiveRecommendation({
    required this.type,
    this.insightType,
    required this.description,
    required this.priority,
    required this.suggestedActions,
  });
}

enum RecommendationType {
  improveInsight,
  expandInsight,
  adjustThreshold,
  modifyLogic,
}

enum RecommendationPriority {
  high,
  medium,
  low,
}
