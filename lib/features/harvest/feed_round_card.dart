import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../feed/feed_provider.dart';
import '../pond_dashboard_provider.dart';
import '../../../shared/constants/feed_phase.dart';
import '../../feed/feed_phase_utils.dart';
import '../../tray/tray_provider.dart';
import '../../tray/tray_log_screen.dart';

class FeedRoundCard extends ConsumerWidget {
  final int round;
  final String time;
  final int currentRound;
  final Function(int) onOpenTray;

  const FeedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.currentRound,
    required this.onOpenTray,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(pondDashboardProvider);
    String? tray = dashboardState.trayResults[round];
    bool isCurrent = round == currentRound;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Round $round • $time"),
          const SizedBox(height: 8),
          Text(
            "${dashboardState.currentFeed.toStringAsFixed(1)} kg",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (tray != null) Text("Tray: $tray"),
          const SizedBox(height: 10),
          _buildCTA(context, ref),
        ],
      ),
    );
  }

  Widget _buildCTA(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(pondDashboardProvider);
    final notifier = ref.read(pondDashboardProvider.notifier);
    final phase = FeedPhaseUtils.getPhase(dashboardState.doc);

    bool isDone = dashboardState.feedDone[round] ?? false;
    String? tray = dashboardState.trayResults[round];
    int doc = dashboardState.doc;

    // Get Notifiers for actions
    final feedNotifier = ref.read(feedProvider(dashboardState.selectedPond).notifier);
    final trayNotifier = ref.read(trayProvider(dashboardState.selectedPond).notifier);

    // Blind Phase
    if (phase == FeedPhase.blind) {
      return ElevatedButton(
        onPressed: () {
          if (!feedNotifier.canFeed(phase: phase, trayLogged: true)) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("⚠️ Validation failed")),
            );
            return;
          }

          feedNotifier.addFeed(
                FeedEntry(
                  doc: doc,
                  round: round,
                  quantity: dashboardState.currentFeed,
                  feedType: "Starter",
                  time: DateTime.now(),
                  wasAdjusted: false,
                ),
              );
          notifier.markFeedDone(round);
        },
        child: const Text("MARK AS FED"),
      );
    }

    // Transition Phase (DOC 16-25)
    if (phase == FeedPhase.transition) {
      if (!isDone) {
        return ElevatedButton(
          onPressed: () {
            feedNotifier.addFeed(
                  FeedEntry(
                    doc: doc,
                    round: round,
                    quantity: dashboardState.currentFeed,
                    feedType: "Grower",
                    time: DateTime.now(),
                    wasAdjusted: dashboardState.trayResults[round] != null,
                  ),
                );
            notifier.markFeedDone(round);
          },
          child: const Text("MARK AS FED"),
        );
      }
      return OutlinedButton(
        onPressed: () => onOpenTray(round),
        child: const Text("LOG TRAY"),
      );
    }

    // Smart Phase (DOC > 25) - Enforce Tray
    if (phase == FeedPhase.smart) {
      final hasDailyTrayLog = trayNotifier.hasTrayLoggedToday;
      
      if (tray == null) {
        return ElevatedButton(
          onPressed: () => onOpenTray(round),
          child: const Text("CHECK TRAY"),
        );
      }

      if (!isDone) {
        return ElevatedButton(
          onPressed: () {
            if (!feedNotifier.canFeed(phase: phase, trayLogged: hasDailyTrayLog)) {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("⚠️ Please log tray check before feeding")),
              );
              return;
            }
            feedNotifier.addFeed(
                  FeedEntry(
                    doc: doc,
                    round: round,
                    quantity: dashboardState.currentFeed,
                    feedType: "Finisher",
                    time: DateTime.now(),
                    wasAdjusted: tray != null,
                  ),
                );
            notifier.markFeedDone(round);
          },
          child: const Text("MARK AS FED"),
        );
      }
    }

    return const SizedBox();
  }
}