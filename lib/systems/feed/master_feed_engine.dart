// Master Feed Engine — Single Source of Truth for all feed computation
//
// Responsibilities:
//   1. Base feed calculation (DOC ramp + density scaling)
//   2. Full pipeline orchestration: base → stage → intelligence → corrections →
//      decision → recommendation
//
// Pipeline (orchestrate / orchestrateForPond):
//   INPUTS (FeedInput from DB)
//     ↓
//   compute()               → base expected feed (DOC ramp, density scaling)
//     ↓
//   FeedStageResolver       → blind | transitional | intelligent
//     ↓
//   FeedIntelligenceEngine  → expected vs actual, deviation, status
//     ↓
//   SmartFeedEngineV2       → apply corrections (tray, growth, environment, FCR)
//     ↓
//   FeedDecisionEngine      → Increase / Reduce / Maintain / Stop
//     ↓
//   FeedRecommendationEngine → next feed quantity and timing
//     ↓
//   OrchestratorResult (returned to caller — NO DB writes here)
//
// Sub-engines are pure helpers called only from here.
// DB persistence lives in FeedService.

import '../../../features/feed/enums/feed_stage.dart';
import '../../../features/tray/enums/tray_status.dart';
import '../../../features/pond/enums/stocking_type.dart';
import '../../../core/validators/feed_input_validator.dart';
import 'package:aqua_rythu/core/utils/logger.dart';
import 'package:aqua_rythu/core/services/feed_safety_service.dart';
import 'package:aqua_rythu/core/services/subscription_gate.dart';
import '../../../core/services/app_config_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import '../growth/fcr_engine.dart'; // DISABLED FOR V1
import 'feed_input_builder.dart';
// import 'smart_feed_engine_v2.dart'; // DISABLED FOR V1 LAUNCH
import '../../../features/feed/models/feed_input.dart';
import '../../../features/feed/models/correction_result.dart';
import '../../../features/feed/models/feed_debug_info.dart';
import '../../../features/feed/models/orchestrator_result.dart';
import 'engine_constants.dart';
import 'feed_calculations.dart';
import 'feed_models.dart';
import 'feed_base_resolver.dart';
import 'feed_base_service.dart';
import 'tray_factor_service.dart';
import 'env_factor_service.dart';
export '../../../features/feed/models/correction_result.dart';
export '../../../features/feed/models/feed_debug_info.dart';
export '../../../features/feed/models/orchestrator_result.dart';

// ── ABSOLUTE SAFETY CAPS ──────────────────────────────────────────────────────

/// Global hard floor — final feed never below this value (kg).
const double kAbsoluteMinFeed = 0.1;

/// Global hard ceiling — final feed never above this value (kg).
const double kAbsoluteMaxFeed = 50.0;

/// Minimum DOC for smart-mode corrections (SmartFeedEngineV2, FCR, intelligence).
/// DOC ≤ this value = blind phase; DOC > this value = smart phase.
const int kSmartModeMinDoc = 30;

// ── VALIDATION MODEL ───────────────────────────────────────────────────────────

/// Result of critical input validation
class ValidationResult {
  final bool isValid;
  final String reason;

  const ValidationResult({required this.isValid, required this.reason});

  factory ValidationResult.valid() =>
      const ValidationResult(isValid: true, reason: '');
  factory ValidationResult.invalid(String reason) =>
      ValidationResult(isValid: false, reason: reason);
}

// ── DEBUG MODEL ───────────────────────────────────────────────────────────────

/// Step-by-step debug output from [MasterFeedEngine.computeWithDebug].
class FeedDebugData {
  final int doc;
  final StockingType stockingType;
  final int density;

  /// Base feed per 100 K shrimp before density scaling (kg).
  final double baseFeed;

  /// After density scaling: baseFeed × (density / 100 000).
  final double adjustedFeed;

  /// Tray adjustment factor (1.0 when tray inactive or no data).
  final double trayFactor;

  /// Raw feed before safety clamp: adjustedFeed × trayFactor.
  final double rawFeed;

  /// Final feed after safety clamp.
  final double finalFeed;

  /// Minimum allowed feed (adjustedFeed × 0.70).
  final double minFeed;

  /// Maximum allowed feed (adjustedFeed × 1.30).
  final double maxFeed;

  /// True when rawFeed was clamped.
  final bool isClamped;

  /// Tray leftover % used (null = no data).
  final double? leftover;

  /// Whether tray adjustment is active for this DOC + stocking type.
  final bool trayActive;

  /// Human-readable reason for tray factor decision.
  final String trayStatusReason;

  /// True when any input was silently clamped to its safe range.
  final bool wasInputClamped;

  const FeedDebugData({
    required this.doc,
    required this.stockingType,
    required this.density,
    required this.baseFeed,
    required this.adjustedFeed,
    required this.trayFactor,
    required this.rawFeed,
    required this.finalFeed,
    required this.minFeed,
    required this.maxFeed,
    required this.isClamped,
    required this.leftover,
    required this.trayActive,
    required this.trayStatusReason,
    required this.wasInputClamped,
  });
}

// ── DEBUG LOGGER ──────────────────────────────────────────────────────────────

void _logFeed(FeedDebugData d) {
  AppLogger.debug(
    '[MasterFeedEngine] DOC=${d.doc} density=${d.density} '
    'base=${d.baseFeed} kg trayFactor=${d.trayFactor} '
    'final=${d.finalFeed} kg',
  );
}

// ── ENGINE ────────────────────────────────────────────────────────────────────

class MasterFeedEngine {
  static const String version = 'v2.0.0';
  static final FeedBaseService _feedBaseService = FeedBaseService();
  static final TrayFactorService _trayFactorService = TrayFactorService();
  static final EnvFactorService _envFactorService = EnvFactorService();

  // ── BASE FEED (DOC RAMP + DENSITY SCALING) ────────────────────────────────

  /// Calculate base expected feed (kg) for a given DOC.
  ///
  /// [doc]             Day of Culture (1-based).
  /// [stockingType]    Stocking type enum.
  /// [density]         Live stocking count (shrimp). Scales linearly.
  ///
  /// NOTE: Tray adjustments are NOT applied here — they belong in SmartFeedEngineV2.
  static double compute({
    required int doc,
    required StockingType stockingType,
    required int density,
  }) {
    return computeWithDebug(
      doc: doc,
      stockingType: stockingType,
      density: density,
    ).finalFeed;
  }

  /// Same as [compute] but returns every intermediate step for the debug panel.
  static FeedDebugData computeWithDebug({
    required int doc,
    required StockingType stockingType,
    required int density,
  }) {
    // ── STEP 0: ZERO SHRIMP SAFETY CHECK ───────────────────────────────────
    if (density <= 0) {
      AppLogger.error(
        '[MasterFeedEngine] ZERO SHRIMP COUNT DETECTED: density=$density. '
        'Feed calculation STOPPED. No minimum feed override applied.',
      );
      return FeedDebugData(
        doc: doc,
        stockingType: stockingType,
        density: density,
        baseFeed: 0.0,
        adjustedFeed: 0.0,
        trayFactor: 1.0,
        rawFeed: 0.0,
        finalFeed: 0.0,
        minFeed: 0.0,
        maxFeed: 0.0,
        isClamped: false,
        leftover: null,
        trayActive: false,
        trayStatusReason: 'Zero shrimp count - feeding stopped',
        wasInputClamped: false,
      );
    }

    // ── Step 0: Validation ────────────────────────────────────────────────
    final int validatedDoc = doc < 1 ? 1 : doc;
    final int validatedDensity = density;

    // ── Step 0b: Input clamping ───────────────────────────────────────────
    final int safeDoc = validatedDoc.clamp(1, 120); // Extended to 120 DOC
    final int safeDensity = validatedDensity.clamp(1000, 1000000);
    final bool wasInputClamped = doc != safeDoc || density != safeDensity;

    // ── Step 1: Base feed (kg per 100 K shrimp) ───────────────────────────
    final double base = docFeedCurve(safeDoc);

    // ── Step 2: Density scaling ───────────────────────────────────────────
    final double adjustedBase = base * (safeDensity / 100000);

    // ── Step 3: Safety clamp (±30%) ───────────────────────────────────────
    final double minFeed = adjustedBase * FeedEngineConstants.minFeedFactor;
    final double maxFeed = adjustedBase * FeedEngineConstants.maxFeedFactor;
    double final_ = adjustedBase.clamp(minFeed, maxFeed);

    // ── Step 3b: Density-proportional hard cap ───────────────────────────
    // kAbsoluteMaxFeed (50 kg) is defined per 100K shrimp. A 500K-shrimp pond
    // legitimately needs up to 250 kg/day at late DOC — the fixed 50 kg cap
    // would silently underfeed by ~47 % at maximum stocking density.
    final double effectiveMaxFeed =
        ((safeDensity / 100000.0) * kAbsoluteMaxFeed)
            .clamp(kAbsoluteMaxFeed, 500.0);
    final_ = final_.clamp(kAbsoluteMinFeed, effectiveMaxFeed);
    if (final_.isNaN || final_.isInfinite) {
      final_ = adjustedBase.clamp(kAbsoluteMinFeed, effectiveMaxFeed);
    }

    final bool clamped = (adjustedBase - final_).abs() > 0.001;

    final result = FeedDebugData(
      doc: safeDoc,
      stockingType: stockingType,
      density: safeDensity,
      baseFeed: double.tryParse(base.toStringAsFixed(3)) ?? base,
      adjustedFeed:
          double.tryParse(adjustedBase.toStringAsFixed(3)) ?? adjustedBase,
      trayFactor: 1.0, // Tray logic removed from base compute
      rawFeed: double.tryParse(adjustedBase.toStringAsFixed(3)) ??
          adjustedBase, // No tray adjustment
      finalFeed: double.tryParse(final_.toStringAsFixed(3)) ?? final_,
      minFeed: double.tryParse(minFeed.toStringAsFixed(3)) ?? minFeed,
      maxFeed: double.tryParse(maxFeed.toStringAsFixed(3)) ?? maxFeed,
      isClamped: clamped,
      leftover: null, // Tray logic removed from base compute
      trayActive: false, // Tray logic removed from base compute
      trayStatusReason: 'Tray handled by SmartFeedEngineV2 only',
      wasInputClamped: wasInputClamped,
    );

    _logFeed(result);
    return result;
  }

  // ── FULL PIPELINE ORCHESTRATION ───────────────────────────────────────────
  // V1 SIMPLIFIED: Single deterministic flow
  // Step 1: Base Feed (DOC ramp + density scaling)
  // Step 2: Tray Factor (simple appetite signal)
  // Step 3: Apply Factor
  // Step 4: Safety Clamp (±30% from base)
  // Step 5: Return result

  /// Run the simplified feed pipeline from a pre-built [FeedInput].
  ///
  /// Pure — no DB writes. Use [orchestrateForPond] when the caller only has
  /// a pondId and needs DB state fetched first.
  static OrchestratorResult orchestrate(
    FeedInput input, {
    // Optional admin config override for testing/future use
    FeedEngineConfig? adminConfigOverride,
  }) {
    // ── STEP 0: CRITICAL DATA VALIDATION ───────────────────────────────────
    final ValidationResult validation = _validateCriticalInputs(input);
    if (!validation.isValid) {
      AppLogger.error(
        '[MasterFeedEngine] CRITICAL DATA VALIDATION FAILED: ${validation.reason}. '
        'Feed calculation STOPPED.',
      );
      return OrchestratorResult.stopFeed(
        reason: validation.reason,
        engineVersion: version,
        doc: input.doc,
      );
    }

    FeedInputValidator.validate(input);

    // ── STEP 0: Admin Panel Controls (with safe defaults) ─────────────────────
    // For synchronous operation, use safe defaults. Real admin controls applied
    // in orchestrateForPond which can be async.
    final feedEngineConfig = adminConfigOverride ??
        const FeedEngineConfig(
          smartFeedEnabled: true,
          blindFeedDocLimit: 30,
          globalFeedMultiplier: 1.0,
          feedKillSwitch: false,
        );

    // Check kill switch - if enabled, stop all feed recommendations
    if (feedEngineConfig.feedKillSwitch) {
      AppLogger.warn(
        '[MasterFeedEngine] FEED KILL SWITCH ACTIVATED - stopping all feed recommendations',
      );
      return OrchestratorResult.stopFeed(
        reason: 'Feed kill switch activated by admin',
        engineVersion: version,
        doc: input.doc,
      );
    }

    // Check smart feed enabled - if disabled, force blind feeding.
    // FREE users are also forced into blind feeding — smart feed is a PRO
    // feature (FeatureIds.smartFeedEngine). Tray/growth corrections are
    // skipped, only the deterministic DOC ramp + density scaling runs.
    final bool forceBlindFeeding =
        !feedEngineConfig.smartFeedEnabled || !SubscriptionGate.isPro;

    // ── STEP 1: Base Feed (using new BaseFeedResolver) ───────────────────
    final stage1Debug = computeWithDebug(
      doc: input.doc,
      stockingType: input.stockingType,
      density: input.seedCount,
    );

    // 🔥 CRITICAL FIX: Use BaseFeedResolver to prevent anchor feed bug
    final baseFeedResult = FeedBaseResolver.resolveBaseFeed(
      doc: input.doc,
      anchorFeed: input.anchorFeed,
      actualFeedYesterday: input.actualFeedYesterday,
      plannedFeed: stage1Debug.finalFeed,
      pondId: input.pondId,
    );
    final baseFeed = baseFeedResult.feedAmount;

    // 🔥 CRITICAL FIX: Validate base feed for smart feeding safety
    FeedBaseResolver.validateSmartFeedBase(input.doc, baseFeed, input.pondId);

    // ── STEP 2: DOC Rule Enforcement ───────────────────────────────────────
    final bool isBlindPhase = input.doc <= 30;

    // Smart feeding activates when: DOC > 30 (sampling removed)
    final bool shouldUseSmartFeeding = !isBlindPhase && input.doc > 30;

    // Force blind feeding if admin disabled smart feed
    final bool useBlindFeeding = forceBlindFeeding || !shouldUseSmartFeeding;

    // ── STEP 3: Factor Pipeline (Base + Tray + Environment) ────────────────
    final baseFeedKg = _feedBaseService.getBaseFeedKg(
      input.doc,
      input.seedCount,
      previousDayFeedKg: input.actualFeedYesterday,
    );
    final currentTrayLeftover =
        _trayFactorService.getLeftoverPercentFromStatuses(input.trayStatuses);
    final historicalLeftover =
        _latestKnownLeftover(input.recentTrayLeftoverPct);
    final leftoverPercent = currentTrayLeftover ?? historicalLeftover ?? -1.0;

    double trayFactor = _trayFactorService.getTrayFactor(leftoverPercent);
    if (useBlindFeeding) {
      trayFactor = 1.0;
    }

    const isRaining = false;
    final phFluctuation = input.phChange.abs() >= 0.5;
    final envFactor = _envFactorService.getEnvFactor(
      isRaining: isRaining,
      temperature: input.temperature,
      dissolvedOxygen: input.dissolvedOxygen,
      phFluctuation: phFluctuation,
    );
    final envReasons = _envFactorService.getEnvReasons(
      isRaining: isRaining,
      temperature: input.temperature,
      dissolvedOxygen: input.dissolvedOxygen,
      phFluctuation: phFluctuation,
    );

    // ── STEP 4: Final feed integration ───────────────────────────────────────
    final rawIntegratedFeed = baseFeedKg * trayFactor * envFactor;
    double feed = rawIntegratedFeed;

    // ── STEP 3.5: Apply Global Multiplier from Admin Panel ───────────────────
    feed = feed * feedEngineConfig.globalFeedMultiplier;

    // ── STEP 4: Safety Clamp (allow true stop, cap unrealistic spikes) ─────
    const minFeed = 0.0;
    final maxFeed = baseFeedKg * FeedEngineConstants.maxFeedFactor;
    if (feed.isNaN || feed.isInfinite || feed < minFeed) {
      feed = minFeed;
    }
    if (maxFeed > 0 && feed > maxFeed) {
      feed = maxFeed;
    }

    final bool wasClamped = (rawIntegratedFeed - feed).abs() > 0.001;
    final clampReason = wasClamped
        ? rawIntegratedFeed > maxFeed
            ? 'Feed capped at maximum allowed feed'
            : 'Feed raised to zero-safe minimum'
        : null;

    // Apply feed safety clamping before final calculation
    final safetyResult = FeedSafetyService().validateFeedCalculation(
      calculatedFeed: double.tryParse(feed.toStringAsFixed(3)) ?? feed,
      pondId: input.pondId,
      baseFeed: baseFeedKg,
      calculationType: 'master_feed_engine',
    );

    var finalFeed = safetyResult.safeAmount;
    if (finalFeed.isNaN || finalFeed.isInfinite || finalFeed < 0) {
      finalFeed = 0.0;
    }
    if (maxFeed > 0 && finalFeed > maxFeed) {
      finalFeed = maxFeed;
    }
    final isCriticalStop = finalFeed == 0.0 &&
        (trayFactor == 0.0 || envFactor == 0.0 || rawIntegratedFeed == 0.0);
    final reductionReasons = _buildReductionReasons(
        trayFactor, envFactor, leftoverPercent, envReasons);
    final confidenceLevel = buildFeedConfidenceLevel(trayFactor, envFactor);
    final confidenceReason = buildFeedConfidenceReason(trayFactor, envFactor);

    // ── STEP 5: Build minimal result objects for backward compatibility ────
    final feedStage = FeedStageResolver.resolve(
      doc: input.doc,
      hasSampling: input.abw != null,
    );

    // Minimal intelligence result
    const intelligence = IntelligenceResult(
      expectedFeed: 0.0,
      status: FeedStatus.onTrack,
    );

    // Updated correction result with tray factor only
    final correction = CorrectionResult(
      baseFeed: baseFeedKg,
      trayFactor: trayFactor,
      finalFeed: finalFeed,
      safetyStatus: finalFeed > 0 ? 'normal' : 'stopped',
      reasons: _buildFactorReasons(
        trayFactor,
        envFactor,
        leftoverPercent,
        useBlindFeeding,
        envReasons,
      ),
      alerts: const [],
      isCriticalStop: isCriticalStop,
      isSmartApplied: !useBlindFeeding,
      wasClamped: wasClamped || safetyResult.wasClamped,
      clampReason: safetyResult.reason ?? clampReason,
    );

    // Minimal decision
    final decision = FeedDecision(
      action: finalFeed > 0 ? 'Maintain Feeding' : 'Stop Feeding',
      deltaKg: finalFeed - baseFeedKg,
      reason: buildFeedExplanation(
        trayFactor,
        envFactor,
        leftoverPercent,
        envReasons: envReasons,
      ),
      recommendations: reductionReasons,
      decisionTrace: [
        'Base Feed: ${baseFeedKg.toStringAsFixed(3)} kg',
        'Tray Factor: ${trayFactor.toStringAsFixed(3)}',
        'Env Factor: ${envFactor.toStringAsFixed(3)}',
        'Final Feed: ${finalFeed.toStringAsFixed(3)} kg',
      ],
      confidence: confidenceLevel,
      confidenceReason: confidenceReason,
    );

    // Minimal recommendation
    final feedsPerDay = input.feedsPerDay ?? 4;
    final recommendation = FeedRecommendation(
      nextFeedKg: finalFeed / feedsPerDay,
      nextFeedTime: DateTime.now().add(const Duration(hours: 4)),
      instruction: finalFeed == 0.0
          ? 'Do not feed'
          : 'Feed ${(finalFeed / feedsPerDay).toStringAsFixed(1)} kg',
    );

    AppLogger.info(
      'FEED_PIPELINE_V1_SIMPLIFIED',
      {
        'doc': input.doc,
        'baseFeed': baseFeedKg,
        'trayFactor': trayFactor,
        'envFactor': envFactor,
        'finalFeed': finalFeed,
        'confidence': confidenceLevel,
        'isClamped': wasClamped || safetyResult.wasClamped,
      },
    );

    // ── STEP 5: Return result ─────────────────────────────────────────────
    return OrchestratorResult(
      baseFeed: baseFeedKg,
      feedStage: feedStage,
      intelligence: intelligence,
      correction: correction,
      decision: decision,
      recommendation: recommendation,
      engineVersion: version,
      debugInfo: FeedDebugInfo(
        doc: input.doc,
        baseFeedPer100k: stage1Debug.baseFeed,
        adjustedFeed: stage1Debug.adjustedFeed,
        minFeed: minFeed,
        maxFeed: maxFeed,
        isBaseFeedClamped: stage1Debug.isClamped,
        wasInputClamped: stage1Debug.wasInputClamped,
        baseFeed: baseFeedKg,
        trayFactor: trayFactor,
        smartFactor: envFactor,
        combinedFactor: trayFactor * envFactor,
        rawCombinedFactor: rawIntegratedFeed,
        fcr: 1.0,
        finalFeed: finalFeed,
        isSmartApplied: false,
        wasClamped: wasClamped || safetyResult.wasClamped,
        clampReason: safetyResult.reason ?? clampReason,
        hasSampling: input.abw != null,
        feedStage: feedStage.name,
        v2Debug: null, // ❌ DISABLED
        // 🔥 NEW: Base feed source tracking for debugging
        baseFeedSource: FeedBaseResolver.sourceToString(baseFeedResult.source),
        baseFeedExplanation: baseFeedResult.explanation,
      ),
    );
  }

  /// Fetch pond state from DB, then run the full pipeline with admin controls.
  ///
  /// Use [FeedService.applyTrayAdjustment] or [FeedService.recalculateFeedPlan]
  /// when you also need to persist the result to feed_rounds.
  static Future<OrchestratorResult> orchestrateForPond(String pondId) async {
    // 🔥 VERIFICATION LOG: Should print ONLY ONCE per pond load (via Controller cache)
    AppLogger.info('🔥 FEED ENGINE CALLED: pond=$pondId');

    // ── STEP 0: Load Admin Config ─────────────────────────────────────────
    final appConfigService = AppConfigService(Supabase.instance.client);
    final feedEngineConfig = await appConfigService.getFeedEngineConfig();

    // Check kill switch - if enabled, stop all feed recommendations
    if (feedEngineConfig.feedKillSwitch) {
      AppLogger.warn(
        '[MasterFeedEngine] FEED KILL SWITCH ACTIVATED - stopping all feed recommendations',
      );
      return OrchestratorResult.stopFeed(
        reason: 'Feed kill switch activated by admin',
        engineVersion: version,
        doc: 0, // We don't know DOC yet
      );
    }

    final input = await FeedInputBuilder.fromDB(pondId);
    return orchestrate(input, adminConfigOverride: feedEngineConfig);
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

  static double? _latestKnownLeftover(List<double> leftovers) {
    for (final leftover in leftovers.reversed) {
      if (!leftover.isNaN && !leftover.isInfinite && leftover >= 0) {
        return leftover;
      }
    }
    return null;
  }

  /// Simple tray factor based on tray status.
  ///
  /// ✅ DETERMINISTIC:
  /// - full > empty → reduce feeding (shrimp not eating) → 0.85
  /// - empty > full → increase feeding (clean trays, good appetite) → 1.1
  /// - balanced or no data → 1.0
  ///
  /// ❌ DISABLED FEATURES:
  /// - Tray history analysis
  /// - ABW-based growth signal
  /// - Water quality factors
  /// - DOC-based conservatism
  static double _simpleTrayFactor(List<TrayStatus>? trays) {
    if (trays == null || trays.isEmpty) {
      return 1.0; // Default — no tray data
    }

    int full = 0;
    int empty = 0;

    for (final status in trays) {
      switch (status) {
        case TrayStatus.full:
          full++;
          break;
        case TrayStatus.completed:
          empty++;
          break;
        case TrayStatus.partial:
          // Neutral — don't count
          break;
      }
    }

    if (full > empty) {
      return 0.92; // More full trays — reduce feeding (less aggressive)
    } else if (empty > full) {
      return 1.05; // More empty trays — increase feeding (less aggressive)
    } else {
      return 1.0; // Balanced — no adjustment
    }
  }

  /// Build list of factor reasons for UI display
  static List<String> _buildFactorReasons(double trayFactor, double envFactor,
      double leftoverPercent, bool useBlindFeeding, List<String> envReasons) {
    final reasons = <String>[];

    if (useBlindFeeding) {
      reasons.add('Blind feeding phase (DOC ≤ 30) - no adjustments');
      return reasons;
    }

    reasons.add('Base Feed: system DOC curve applied');

    if (trayFactor != 1.0) {
      reasons.add(
          'Tray Factor: ${trayFactor.toStringAsFixed(2)} (leftover ${leftoverPercent.toStringAsFixed(1)}%)');
    }

    if (envFactor != 1.0) {
      final reasonText =
          envReasons.isEmpty ? '' : ' (${envReasons.join(', ')})';
      reasons.add('Env Factor: ${envFactor.toStringAsFixed(2)}$reasonText');
    }

    return reasons;
  }

  static List<String> _buildReductionReasons(
    double trayFactor,
    double envFactor,
    double leftoverPercent,
    List<String> envReasons,
  ) {
    final reasons = <String>[];

    if (trayFactor < 1.0) {
      final trayReason = _trayFactorService.getTrayReason(leftoverPercent);
      if (trayReason != null) reasons.add(trayReason);
    }

    if (envFactor < 1.0) {
      reasons.addAll(envReasons);
    }

    return reasons;
  }

  static String buildFeedExplanation(
    double trayFactor,
    double envFactor,
    double leftoverPercent, {
    List<String> envReasons = const [],
  }) {
    if (trayFactor == 0.0 || envFactor == 0.0) {
      if (envFactor == 0.0) {
        final reason = envReasons.isEmpty ? 'water stress' : envReasons.first;
        return 'Feeding stopped due to $reason';
      }
      return 'Do not feed due to high tray leftover';
    }

    if (trayFactor < 1.0) {
      return 'Feed reduced due to ${leftoverPercent.toStringAsFixed(0)}% tray leftover';
    }

    if (envFactor < 1.0) {
      return 'Feed reduced due to water environment condition';
    }

    return 'Feed on track';
  }

  static String buildFeedConfidenceLevel(double trayFactor, double envFactor) {
    return (envFactor < 1.0 || trayFactor < 1.0) ? 'Medium' : 'Normal';
  }

  static String buildFeedConfidenceReason(double trayFactor, double envFactor) {
    return (envFactor < 1.0 || trayFactor < 1.0)
        ? 'Low confidence due to stress'
        : 'Normal feeding confidence';
  }

  /// Build factor explanations for UI display
  static Map<String, String> _buildFactorExplanations(double trayFactor) {
    final explanations = <String, String>{};

    if (trayFactor != 1.0) {
      if (trayFactor >= 1.10) {
        explanations['tray'] = 'Clean trays — good appetite';
      } else if (trayFactor >= 1.05) {
        explanations['tray'] = 'Light leftover — acceptable';
      } else if (trayFactor <= 0.85) {
        explanations['tray'] = 'High leftover — reduce feeding';
      } else {
        explanations['tray'] = 'Moderate leftover — stable';
      }
    }

    return explanations;
  }

  /// Validate critical inputs that must stop feed calculation if invalid
  static ValidationResult _validateCriticalInputs(FeedInput input) {
    // ── ZERO SHRIMP CHECK ────────────────────────────────────────────────
    if (input.seedCount <= 0) {
      return ValidationResult.invalid(
        'ZERO SHRIMP COUNT: seedCount=${input.seedCount}. Cannot calculate feed.',
      );
    }

    // ── DOC VALIDATION ───────────────────────────────────────────────────
    if (input.doc < 1) {
      return ValidationResult.invalid(
        'INVALID DOC: doc=${input.doc}. Must be >= 1.',
      );
    }

    // ── CRITICAL WATER QUALITY CHECK ─────────────────────────────────────
    if (input.dissolvedOxygen < 2.0) {
      return ValidationResult.invalid(
        'CRITICAL DO: dissolvedOxygen=${input.dissolvedOxygen} mg/L. Below safe threshold.',
      );
    }

    // ── EXTREME AMMONIA CHECK ────────────────────────────────────────────
    if (input.ammonia > 2.0) {
      return ValidationResult.invalid(
        'CRITICAL AMMONIA: ammonia=${input.ammonia} ppm. Above safe threshold.',
      );
    }

    // All critical inputs valid
    return ValidationResult.valid();
  }
}
