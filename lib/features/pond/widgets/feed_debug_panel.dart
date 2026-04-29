import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/feed_debug_logger.dart';
import '../pond_dashboard_provider.dart';

/// Hidden debug panel for field validation of feed operations
/// Activated by tapping 5 times on the app title in debug builds
class FeedDebugPanel extends ConsumerStatefulWidget {
  const FeedDebugPanel({super.key});

  @override
  ConsumerState<FeedDebugPanel> createState() => _FeedDebugPanelState();
}

class _FeedDebugPanelState extends ConsumerState<FeedDebugPanel> {
  bool _isVisible = false;
  List<String> _logs = [];
  Map<int, double?> _actualDbFeedValues = {}; // Cache for actual DB values

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await FeedDebugLogger.getRecentLogs(count: 20);

    // Also fetch actual DB feed values for current pond
    final pondState = ref.read(pondDashboardProvider);
    final actualDbValues = <int, double?>{};

    if (pondState.selectedPond.isNotEmpty) {
      for (final round in pondState.roundFeedAmounts.keys) {
        try {
          final feedLogs = await Supabase.instance.client
              .from('feed_logs')
              .select('feed_given')
              .eq('pond_id', pondState.selectedPond)
              .eq('doc', pondState.doc)
              .eq('round', round)
              .order('created_at', ascending: false)
              .limit(1);

          if (feedLogs.isNotEmpty) {
            actualDbValues[round] =
                (feedLogs.first['feed_given'] as num?)?.toDouble();
          }
        } catch (e) {
          // Silently fail, will use state value as fallback
        }
      }
    }

    setState(() {
      _logs = logs;
      _actualDbFeedValues = actualDbValues;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!FeedDebugLogger.isDebugMode && !_isVisible) {
      return const SizedBox.shrink();
    }

    final pondState = ref.watch(pondDashboardProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🔴 FEED DEBUG PANEL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _loadLogs,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh logs',
                  ),
                  IconButton(
                    onPressed: () => setState(() => _isVisible = !_isVisible),
                    icon: Icon(
                        _isVisible ? Icons.expand_less : Icons.expand_more),
                    tooltip: 'Toggle visibility',
                  ),
                ],
              ),
            ],
          ),
          if (_isVisible) ...[
            const SizedBox(height: 12),

            // Current pond state info
            _buildSection('CURRENT STATE', [
              'Pond: ${pondState.selectedPond}',
              'DOC: ${pondState.doc}',
              'Feed Loading: ${pondState.isFeedLoading}',
              'Last Feed Time: ${pondState.lastFeedTime?.toIso8601String() ?? "Never"}',
              'Feed Status: ${pondState.roundFeedStatus}',
            ]),

            const SizedBox(height: 12),

            // Data source explanation
            _buildSection('DATA SOURCES (ACTUAL DB VALUES)', [
              '📊 Feed Entered (User): Comes from actualQty parameter in markFeedDone()',
              '💾 Feed Saved (Database): Fetched directly from feed_logs.feed_given column',
              '⚙️ Recommended Feed (Engine): Comes from state.roundFeedAmounts[round]',
              '✅ Feed Saved value = ACTUAL stored DB value (not assumed)',
              '🔄 Refresh: Click refresh button to fetch latest DB values',
            ]),

            const SizedBox(height: 12),

            // Feed amounts comparison with difference calculation
            if (pondState.roundFeedAmounts.isNotEmpty) ...[
              _buildFeedComparisonSection(pondState),
              const SizedBox(height: 12),
            ],

            // Engine recommendation
            if (pondState.feedDebugInfo != null) ...[
              _buildSection('SMART FEED ENGINE', [
                'Base Feed: ${pondState.feedDebugInfo!.baseFeed.toStringAsFixed(2)} kg',
                'Tray Factor: ${pondState.feedDebugInfo!.trayFactor.toStringAsFixed(2)}',
                'Env Factor: ${pondState.feedDebugInfo!.smartFactor.toStringAsFixed(2)}',
                'Final Feed: ${pondState.feedDebugInfo!.finalFeed.toStringAsFixed(2)} kg',
                'Confidence: ${pondState.decision?.confidence ?? "Normal"}',
                if (pondState.decision?.confidenceReason.isNotEmpty == true)
                  pondState.decision!.confidenceReason,
              ]),
              const SizedBox(height: 12),
            ],

            // Tray factor breakdown
            if (pondState.feedDebugInfo != null) ...[
              _buildTrayFactorSection(pondState.feedDebugInfo!),
              const SizedBox(height: 12),
            ],

            if (pondState.recommendation != null) ...[
              _buildSection('ENGINE RECOMMENDATION', [
                'Next Feed: ${pondState.recommendation!.nextFeedKg.toStringAsFixed(2)}kg',
                'Next Time: ${pondState.recommendation!.nextFeedTime.toIso8601String()}',
                'Instruction: ${pondState.recommendation!.instruction}',
              ]),
              const SizedBox(height: 12),
            ],

            // Recent debug logs
            _buildSection('RECENT LOGS', _logs.take(10).toList()),

            const SizedBox(height: 12),

            // Debug controls
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await FeedDebugLogger.clearLogs();
                    await _loadLogs();
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Clear Logs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pondId = pondState.selectedPond;
                    if (pondId.isNotEmpty) {
                      await _verifyDBTruth(pondId, pondState.doc);
                    }
                  },
                  icon: const Icon(Icons.fact_check, size: 16),
                  label: const Text('Verify DB'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pondId = pondState.selectedPond;
                    if (pondId.isNotEmpty) {
                      final feedLogs = await FeedDebugLogger.queryFeedLogs(
                        pondId: pondId,
                        doc: pondState.doc,
                      );
                      final feedRounds = await FeedDebugLogger.queryFeedRounds(
                        pondId: pondId,
                        doc: pondState.doc,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'DB: ${feedLogs.length} logs, ${feedRounds.length} rounds',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.storage, size: 16),
                  label: const Text('Query DB'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedComparisonSection(PondDashboardState pondState) {
    final items = <String>[];

    for (final entry in pondState.roundFeedAmounts.entries) {
      final round = entry.key;
      final calculatedFeed = entry.value;
      final finalFeed =
          pondState.roundFinalFeedAmounts[round] ?? calculatedFeed;
      final isEdited = pondState.roundIsManuallyEdited[round] == true;

      // Use actual DB value if available, otherwise fallback to state value
      final dbFeedSaved = _actualDbFeedValues[round] ?? finalFeed;

      // Calculate difference percentage using actual DB value
      final difference = calculatedFeed > 0
          ? ((dbFeedSaved - calculatedFeed) / calculatedFeed * 100)
          : 0.0;

      // Determine color based on difference
      String color;
      if (difference.abs() <= 10) {
        color = '🟢'; // Green
      } else if (difference.abs() <= 25) {
        color = '🟡'; // Yellow
      } else {
        color = '🔴'; // Red
      }

      // Add indicator if we're using actual DB value vs fallback
      final dbIndicator = _actualDbFeedValues[round] != null ? '✅' : '⚠️';

      items.add('Round $round: $color${difference.toStringAsFixed(1)}% '
          'Feed Entered (User): ${finalFeed.toStringAsFixed(2)}kg '
          'Feed Saved (Database): ${dbFeedSaved.toStringAsFixed(2)}kg $dbIndicator '
          'Recommended Feed (Engine): ${calculatedFeed.toStringAsFixed(2)}kg '
          '${isEdited ? "[EDITED]" : ""}');
    }

    return _buildSection('FEED COMPARISON - ACTUAL DB VALUES', items);
  }

  Future<void> _verifyDBTruth(String pondId, int doc) async {
    try {
      // Fetch fresh data from DB
      final feedRounds = await FeedDebugLogger.queryFeedRounds(
        pondId: pondId,
        doc: doc,
      );

      // Get current state values
      final pondState = ref.read(pondDashboardProvider);
      final stateRounds = pondState.roundFeedAmounts;
      final stateFinalRounds = pondState.roundFinalFeedAmounts;

      // Compare DB vs State
      final mismatches = <String>[];

      for (final dbRound in feedRounds) {
        final round = dbRound['round'] as int;
        final dbAmount = (dbRound['feed_amount'] as num?)?.toDouble() ?? 0.0;
        final stateAmount =
            stateFinalRounds[round] ?? stateRounds[round] ?? 0.0;

        if ((dbAmount - stateAmount).abs() > 0.01) {
          mismatches.add(
              'Round $round: DB=${dbAmount.toStringAsFixed(2)}kg vs State=${stateAmount.toStringAsFixed(2)}kg');
        }
      }

      if (mismatches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ DB Truth Check: All values match!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('❌ DB Truth Check: ${mismatches.length} mismatches found'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () => _showMismatchDetails(mismatches),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('DB Truth Check failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMismatchDetails(List<String> mismatches) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DB Truth Check Mismatches'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: mismatches
                .map((mismatch) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        mismatch,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayFactorSection(dynamic feedDebugInfo) {
    final baseFeed = feedDebugInfo.baseFeed ?? 0.0;
    final trayFactor = feedDebugInfo.trayFactor ?? 0.0;
    final finalFeed = feedDebugInfo.finalFeed ?? 0.0;
    final delta = finalFeed - baseFeed;

    String factorDescription;
    if (trayFactor > 0.05) {
      factorDescription =
          'Increase (+${(trayFactor * 100).toStringAsFixed(0)}%)';
    } else if (trayFactor < -0.05) {
      factorDescription = 'Reduce (${(trayFactor * 100).toStringAsFixed(0)}%)';
    } else {
      factorDescription = 'No change';
    }

    final items = <String>[
      'Tray Factor: ${trayFactor.toStringAsFixed(2)} → $factorDescription',
      'Previous Feed: ${baseFeed.toStringAsFixed(2)} kg',
      'New Feed: ${finalFeed.toStringAsFixed(2)} kg',
      if (delta.abs() > 0.01)
        'Delta: ${delta > 0 ? "+" : ""}${delta.toStringAsFixed(2)} kg (${delta > 0 ? "increase" : "decrease"})',
    ];

    return _buildSection('TRAY FACTOR BREAKDOWN', items);
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map((item) => Text(
                      item,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// Hidden debug toggle button - can be placed in app bar
class DebugToggleTrigger extends StatefulWidget {
  final Widget child;

  const DebugToggleTrigger({super.key, required this.child});

  @override
  State<DebugToggleTrigger> createState() => _DebugToggleTriggerState();
}

class _DebugToggleTriggerState extends State<DebugToggleTrigger> {
  int _tapCount = 0;
  DateTime? _lastTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        if (_lastTap != null && now.difference(_lastTap!).inSeconds > 2) {
          _tapCount = 0;
        }

        _tapCount++;
        _lastTap = now;

        if (_tapCount >= 5) {
          setState(() {
            FeedDebugLogger.setDebugMode(!FeedDebugLogger.isDebugMode);
          });
          _tapCount = 0;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Debug mode ${FeedDebugLogger.isDebugMode ? "ENABLED" : "DISABLED"}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: widget.child,
    );
  }
}
