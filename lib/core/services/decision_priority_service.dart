/// Decision Priority Service - implements strict decision priority system
/// Ensures only the most critical and safe decisions are presented to farmers
library;

import '../models/safe_decision_engine.dart';
import '../models/real_world_anchors.dart';
import '../utils/logger.dart';

/// Minimum confidence required for moderate actions
const double MIN_CONFIDENCE_FOR_MODERATE_ACTION = 0.6;

class DecisionPriorityService {
  static DecisionPriorityService? _instance;
  static DecisionPriorityService get instance =>
      _instance ??= DecisionPriorityService._();

  DecisionPriorityService._();

  /// Apply strict priority filtering to decisions
  static PrioritizedDecision prioritizeDecision({
    required SafeProfitDecision safeDecision,
    required FarmAnchors anchors,
    required DecisionHistory history,
  }) {
    // Priority 1: Safety check - if farm is unstable, only maintenance decisions
    if (!anchors.isStable) {
      return PrioritizedDecision(
        decision: _createStabilityDecision(anchors),
        priority: PriorityLevel.stability_first,
        reasoning: 'Farm stability requires attention before any optimizations',
        canImplement: false,
        implementationBlocks: ['Farm stability below threshold'],
      );
    }

    // Priority 2: Low confidence mode - only monitoring decisions
    if (anchors.confidenceLevel == ConfidenceLevel.very_low ||
        anchors.confidenceLevel == ConfidenceLevel.low) {
      return PrioritizedDecision(
        decision: _createLowConfidenceDecision(anchors, safeDecision),
        priority: PriorityLevel.monitoring_only,
        reasoning: 'Low confidence in data - monitoring only mode activated',
        canImplement: true,
        implementationBlocks: [],
      );
    }

    // Priority 3: Check for critical safety issues
    final criticalIssues = _identifyCriticalSafetyIssues(safeDecision, anchors);
    if (criticalIssues.isNotEmpty) {
      return PrioritizedDecision(
        decision: _createSafetyDecision(criticalIssues, anchors),
        priority: PriorityLevel.critical_safety,
        reasoning:
            'Critical safety issues detected - immediate attention required',
        canImplement: true,
        implementationBlocks: [],
      );
    }

    // Priority 4: Decision fatigue check - limit decisions per day
    if (!history.canMakeMoreDecisions) {
      return PrioritizedDecision(
        decision: _createDecisionFatigueDecision(history),
        priority: PriorityLevel.decision_fatigue,
        reasoning:
            'Maximum decisions reached for today - prevent decision fatigue',
        canImplement: false,
        implementationBlocks: ['Daily decision limit reached'],
      );
    }

    // Priority 5: Economic decisions with safety validation
    final validatedDecision =
        _validateEconomicDecision(safeDecision.primaryDecision, anchors);
    if (validatedDecision != null) {
      return PrioritizedDecision(
        decision: validatedDecision,
        priority: _calculateEconomicPriority(validatedDecision, anchors),
        reasoning: 'Economic opportunity validated against safety constraints',
        canImplement: true,
        implementationBlocks: [],
      );
    }

    // Priority 6: Default to maintenance
    return PrioritizedDecision(
      decision: _createDefaultMaintenanceDecision(anchors),
      priority: PriorityLevel.maintenance,
      reasoning: 'No critical issues - continue with maintenance monitoring',
      canImplement: true,
      implementationBlocks: [],
    );
  }

  /// Identify critical safety issues
  static List<SafetyIssue> _identifyCriticalSafetyIssues(
      SafeProfitDecision safeDecision, FarmAnchors anchors) {
    final issues = <SafetyIssue>[];

    // Check water quality indicators
    if (anchors.environmentalStressScore > 0.8) {
      issues.add(const SafetyIssue(
        type: SafetyIssueType.water_quality,
        severity: SafetySeverity.critical,
        description: 'High environmental stress detected',
        immediateAction: 'Test water parameters immediately',
        monitoringRequired: true,
      ));
    }

    // Check for recent mortality
    if (anchors.hasRecentMortality) {
      issues.add(const SafetyIssue(
        type: SafetyIssueType.mortality,
        severity: SafetySeverity.critical,
        description: 'Recent mortality event detected',
        immediateAction: 'Investigate cause and stop feed changes',
        monitoringRequired: true,
      ));
    }

    // Check data freshness
    if (anchors.daysSinceLastSample > 21) {
      issues.add(SafetyIssue(
        type: SafetyIssueType.data_freshness,
        severity: SafetySeverity.high,
        description:
            'Sampling data very old (${anchors.daysSinceLastSample} days)',
        immediateAction: 'Conduct emergency sampling',
        monitoringRequired: false,
      ));
    }

    // Check tray response
    if (anchors.trayResponseScore < 0.5) {
      issues.add(SafetyIssue(
        type: SafetyIssueType.feeding_response,
        severity: SafetySeverity.high,
        description:
            'Very poor tray response (${(anchors.trayResponseScore * 100).toStringAsFixed(0)}%)',
        immediateAction: 'Reduce feed immediately and investigate',
        monitoringRequired: true,
      ));
    }

    return issues;
  }

  /// Validate economic decision against safety constraints
  static SafePrimaryDecision? _validateEconomicDecision(
      SafePrimaryDecision decision, FarmAnchors anchors) {
    // Check confidence threshold
    if (decision.confidenceRange.min < MIN_CONFIDENCE_FOR_MODERATE_ACTION) {
      AppLogger.info(
          'Decision confidence too low: ${decision.confidenceRange.min}');
      return null;
    }

    // Check safety constraints compliance
    final safetyConstraints = decision.safetyConstraints;
    final criticalConstraints = safetyConstraints.where((constraint) =>
        constraint.contains('critical') ||
        constraint.contains('urgent') ||
        constraint.contains('immediate'));

    if (criticalConstraints.isNotEmpty) {
      AppLogger.warn(
          'Critical safety constraints prevent decision: ${criticalConstraints.join(', ')}');
      return null;
    }

    // Check implementation feasibility
    if (!anchors.laborAvailable && decision.timeToImplement.inDays <= 1) {
      AppLogger.info('Labor not available for immediate implementation');
      return null;
    }

    if (!anchors.marketAccess &&
        decision.type == SafeDecisionType.harvestTiming) {
      AppLogger.info('Market access not available for harvest decision');
      return null;
    }

    return decision;
  }

  /// Calculate economic priority level
  static PriorityLevel _calculateEconomicPriority(
      SafePrimaryDecision decision, FarmAnchors anchors) {
    final value = decision.valueRange.average;
    final confidence = decision.confidenceRange.average;

    // High value + high confidence = high priority
    if (value > 10000 && confidence > 0.8) {
      return PriorityLevel.high_value;
    }

    // Medium value + good confidence = medium priority
    if (value > 5000 && confidence > 0.6) {
      return PriorityLevel.medium_value;
    }

    // Low value or low confidence = low priority
    if (value > 1000 && confidence > 0.5) {
      return PriorityLevel.low_value;
    }

    return PriorityLevel.maintenance;
  }

  // Decision creation methods

  static SafePrimaryDecision _createStabilityDecision(FarmAnchors anchors) {
    return const SafePrimaryDecision(
      type: SafeDecisionType.maintenance,
      title: '🔒 Farm Stability Mode Active',
      description:
          'Farm conditions require stabilization. Focus on basic operations only.',
      confidenceRange: ConfidenceRange(0.3, 0.5),
      valueRange: ValueRange(0, 0),
      urgency: DecisionUrgency.urgent,
      actionItems: [
        'Test water quality immediately',
        'Check shrimp health and behavior',
        'Review recent changes and stress factors',
        'Maintain current feeding rates',
      ],
      safetyConstraints: [
        'No feed adjustments until stable',
        'No harvest planning until stable',
        'Monitor closely for 48-72 hours',
      ],
      timeToImplement: Duration(days: 3),
    );
  }

  static SafePrimaryDecision _createLowConfidenceDecision(
      FarmAnchors anchors, SafeProfitDecision safeDecision) {
    return const SafePrimaryDecision(
      type: SafeDecisionType.maintenance,
      title: '📊 Low Confidence - Monitoring Mode',
      description:
          'Data confidence is low. Focus on data collection and basic monitoring.',
      confidenceRange: ConfidenceRange(0.3, 0.5),
      valueRange: ValueRange(0, 0),
      urgency: DecisionUrgency.medium,
      actionItems: [
        'Conduct fresh sampling',
        'Check tray responses',
        'Verify water quality parameters',
        'Review data collection procedures',
      ],
      safetyConstraints: [
        'No major feed adjustments',
        'No harvest decisions',
        'Conservative approach only',
      ],
      timeToImplement: Duration(days: 7),
    );
  }

  static SafePrimaryDecision _createSafetyDecision(
      List<SafetyIssue> issues, FarmAnchors anchors) {
    final criticalIssues =
        issues.where((i) => i.severity == SafetySeverity.critical);
    final primaryIssue =
        criticalIssues.isNotEmpty ? criticalIssues.first : issues.first;

    return SafePrimaryDecision(
      type: SafeDecisionType.maintenance,
      title: '🚨 Safety Alert: ${primaryIssue.type.name}',
      description: primaryIssue.description,
      confidenceRange: const ConfidenceRange(0.8, 0.95),
      valueRange:
          const ValueRange(0, 0), // Safety decisions don't have direct monetary value
      urgency: DecisionUrgency.urgent,
      actionItems: [
        primaryIssue.immediateAction,
        if (primaryIssue.monitoringRequired)
          'Monitor closely for next 24 hours',
        'Document all observations',
        'Be prepared to escalate if conditions worsen',
      ],
      safetyConstraints: [
        'No feed changes until resolved',
        'No harvest activities until resolved',
        'Daily monitoring required',
        'Have emergency contacts ready',
      ],
      timeToImplement: const Duration(hours: 4),
    );
  }

  static SafePrimaryDecision _createDecisionFatigueDecision(
      DecisionHistory history) {
    return const SafePrimaryDecision(
      type: SafeDecisionType.maintenance,
      title: '📋 Daily Decision Limit Reached',
      description:
          'Maximum decisions (${SafeDecisionEngine.MAX_DECISIONS_PER_DAY}) reached for today. Preventing decision fatigue.',
      confidenceRange: ConfidenceRange(0.9, 1.0),
      valueRange: ValueRange(0, 0),
      urgency: DecisionUrgency.low,
      actionItems: [
        'Focus on routine monitoring',
        'Review today\'s implemented decisions',
        'Plan for tomorrow\'s decisions',
        'Rest and recharge',
      ],
      safetyConstraints: [
        'No new decisions until tomorrow',
        'Only emergency actions allowed',
        'Maintain current practices',
      ],
      timeToImplement: Duration(days: 1),
    );
  }

  static SafePrimaryDecision _createDefaultMaintenanceDecision(
      FarmAnchors anchors) {
    return const SafePrimaryDecision(
      type: SafeDecisionType.maintenance,
      title: '📊 Farm Operating Normally',
      description:
          'All parameters within safe ranges. Continue with standard monitoring and maintenance.',
      confidenceRange: ConfidenceRange(0.7, 0.9),
      valueRange: ValueRange(0, 0),
      urgency: DecisionUrgency.low,
      actionItems: [
        'Continue regular monitoring',
        'Maintain current feeding practices',
        'Check water quality daily',
        'Observe shrimp behavior',
      ],
      safetyConstraints: [
        'No major changes without consultation',
        'Maintain current practices',
        'Monitor for any changes',
      ],
      timeToImplement: Duration(days: 7),
    );
  }
}

class PrioritizedDecision {
  final SafePrimaryDecision decision;
  final PriorityLevel priority;
  final String reasoning;
  final bool canImplement;
  final List<String> implementationBlocks;

  const PrioritizedDecision({
    required this.decision,
    required this.priority,
    required this.reasoning,
    required this.canImplement,
    required this.implementationBlocks,
  });

  /// Get priority text
  String get priorityText {
    switch (priority) {
      case PriorityLevel.critical_safety:
        return 'Critical Safety';
      case PriorityLevel.stability_first:
        return 'Stability First';
      case PriorityLevel.high_value:
        return 'High Value';
      case PriorityLevel.medium_value:
        return 'Medium Value';
      case PriorityLevel.low_value:
        return 'Low Value';
      case PriorityLevel.monitoring_only:
        return 'Monitoring Only';
      case PriorityLevel.decision_fatigue:
        return 'Decision Fatigue';
      case PriorityLevel.maintenance:
        return 'Maintenance';
    }
  }

  /// Get priority color
  String get priorityColor {
    switch (priority) {
      case PriorityLevel.critical_safety:
        return '#E53935';
      case PriorityLevel.stability_first:
        return '#FF8F00';
      case PriorityLevel.high_value:
        return '#006A3A';
      case PriorityLevel.medium_value:
        return '#006A3A';
      case PriorityLevel.low_value:
        return '#006A3A';
      case PriorityLevel.monitoring_only:
        return '#FFC107';
      case PriorityLevel.decision_fatigue:
        return '#9E9E9E';
      case PriorityLevel.maintenance:
        return '#9E9E9E';
    }
  }

  /// Check if decision requires immediate action
  bool get requiresImmediateAction {
    return priority == PriorityLevel.critical_safety ||
        priority == PriorityLevel.stability_first ||
        decision.urgency == DecisionUrgency.urgent;
  }

  /// Get implementation status
  ImplementationStatus get implementationStatus {
    if (!canImplement) {
      return ImplementationStatus.blocked;
    }
    if (implementationBlocks.isNotEmpty) {
      return ImplementationStatus.partially_blocked;
    }
    return ImplementationStatus.ready;
  }
}

class SafetyIssue {
  final SafetyIssueType type;
  final SafetySeverity severity;
  final String description;
  final String immediateAction;
  final bool monitoringRequired;

  const SafetyIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.immediateAction,
    required this.monitoringRequired,
  });
}

enum PriorityLevel {
  critical_safety, // Immediate safety issues
  stability_first, // Farm stability problems
  high_value, // High economic value with safety
  medium_value, // Medium economic value with safety
  low_value, // Low economic value with safety
  monitoring_only, // Low confidence - monitoring only
  decision_fatigue, // Too many decisions today
  maintenance, // Routine maintenance
}

enum SafetyIssueType {
  water_quality,
  mortality,
  data_freshness,
  feeding_response,
  environmental_stress,
}

enum SafetySeverity {
  critical,
  high,
  medium,
  low,
}

enum ImplementationStatus {
  ready,
  partially_blocked,
  blocked,
}
