import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/feed_result.dart';
import '../debug/smart_feed_debug_screen.dart';
import '../debug/smart_feed_debug_provider.dart';
import '../../core/utils/smart_feed_debug_helper.dart';
import '../../core/engines/master_feed_engine.dart';

/// Example: Smart Feed Screen with Debug Dashboard Integration
/// 
/// This shows how to:
/// 1. Calculate feed using your smart feed engine
/// 2. Convert results to FeedResult
/// 3. Display and navigate to debug dashboard
class SmartFeedScreenExample extends ConsumerStatefulWidget {
  final String pondId;
  final int doc;

  const SmartFeedScreenExample({
    super.key,
    required this.pondId,
    required this.doc,
  });

  @override
  ConsumerState<SmartFeedScreenExample> createState() =>
      _SmartFeedScreenExampleState();
}

class _SmartFeedScreenExampleState extends ConsumerState<SmartFeedScreenExample> {
  late Future<FeedResult> _feedResultFuture;

  @override
  void initState() {
    super.initState();
    _feedResultFuture = _calculateFeedWithDebug();
  }

  /// Calculate feed and build debug result
  Future<FeedResult> _calculateFeedWithDebug() async {
    try {
      // 1. Load inputs (your existing code)
      // final input = await FeedInputBuilder.fromDB(widget.pondId);

      // 2. Run engine (your existing code)
      // final engineOutput = MasterFeedEngine.run(input);

      // MOCK DATA FOR EXAMPLE
      final engineOutput = _mockEngineOutput();
      final double docFeed = 11.25;
      final double? biomassFeed = 10.8;
      final double? abw = 12.5;

      // 3. Generate explanation
      final explanation = SmartFeedDebugHelper.generateExplanation(
        source: SmartFeedDebugHelper.determineFeedSource(abw: abw),
        fcrFactor: engineOutput.factors['fcr'] as double?,
        trayFactor: engineOutput.factors['tray'] as double?,
        growthFactor: engineOutput.factors['growth'] as double?,
        finalFactor: engineOutput.finalFactor,
      );

      // 4. Calculate confidence
      final confidence = SmartFeedDebugHelper.calculateConfidenceScore(
        hasRecentSampling: abw != null,
        hasTrayData: engineOutput.factors['tray'] != null,
        fcrFactor: engineOutput.factors['fcr'] as double?,
        growthFactor: engineOutput.factors['growth'] as double?,
      );

      // 5. Build FeedResult
      return SmartFeedDebugHelper.buildFeedResult(
        engineOutput: engineOutput,
        docFeed: docFeed,
        biomassFeed: biomassFeed,
        abw: abw,
        doc: widget.doc,
        explanation: explanation,
        confidenceScore: confidence,
      );
    } catch (e) {
      // Handle error
      return _mockFeedResult();
    }
  }

  /// Navigate to debug dashboard
  void _showDebugDashboard(FeedResult result) {
    // Optional: Save to provider for later access
    ref.read(smartFeedDebugProvider.notifier).setFeedResult(result);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartFeedDebugScreen(data: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Feed"),
      ),
      body: FutureBuilder<FeedResult>(
        future: _feedResultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final feedResult = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Main feed display ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Final Feed Recommendation"),
                      const SizedBox(height: 8),
                      Text(
                        "${feedResult.finalFeed.toStringAsFixed(2)} kg",
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Mode: ${feedResult.source == FeedSource.doc ? "DOC" : "Biomass + FCR (Smart)"}",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Quick breakdown ────────────────────────────────────────
                Text(
                  "Calculation Breakdown",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  "DOC Feed",
                  feedResult.docFeed,
                ),
                if (feedResult.biomassFeed != null)
                  _buildBreakdownRow(
                    "Biomass Feed",
                    feedResult.biomassFeed!,
                  ),
                const Divider(),
                _buildBreakdownRow(
                  "Final Feed",
                  feedResult.finalFeed,
                  bold: true,
                  highlight: true,
                ),

                const SizedBox(height: 24),

                // ── Quick explanation ──────────────────────────────────────
                Text(
                  "Why This Feed?",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Text(feedResult.explanation),
                ),

                const SizedBox(height: 24),

                // ── Confidence indicator ───────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: feedResult.confidenceScore,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      feedResult.confidenceScore > 0.8
                          ? Colors.green
                          : feedResult.confidenceScore > 0.6
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Confidence: ${(feedResult.confidenceScore * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Debug dashboard button ─────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDebugDashboard(feedResult),
                    icon: const Icon(Icons.bug_report),
                    label: const Text("View Detailed Analysis"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Additional action buttons ──────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Implement feed now logic
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Apply Feed"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Implement adjustment logic
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text("Adjust"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double value, {
    bool bold = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            "${value.toStringAsFixed(2)} kg",
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.green : null,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── MOCK DATA FOR EXAMPLE ──────────────────────────────────────────────────

  /// Mock engine output for example
  _MockFeedOutput _mockEngineOutput() {
    return _MockFeedOutput(
      finalFeed: 10.2,
      finalFactor: 0.91,
      factors: {
        'fcr': 0.91,
        'tray': null,
        'growth': 1.0,
      },
    );
  }

  /// Mock FeedResult for example
  FeedResult _mockFeedResult() {
    return FeedResult(
      finalFeed: 10.2,
      source: FeedSource.biomass,
      docFeed: 11.25,
      biomassFeed: 10.8,
      fcrFactor: 0.91,
      trayFactor: null,
      growthFactor: 1.0,
      explanation:
          "• Biomass detected from last sampling\n"
          "• FCR = 1.9 → Overfeeding risk\n"
          "• Feed reduced by 8%\n"
          "• Monitor tray after next feed",
      confidenceScore: 0.82,
    );
  }
}

/// Mock FeedOutput for example (replace with actual MasterFeedEngine.run result)
class _MockFeedOutput {
  final double finalFeed;
  final double finalFactor;
  final Map<String, double?> factors;

  _MockFeedOutput({
    required this.finalFeed,
    required this.finalFactor,
    required this.factors,
  });
}
