import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum FeedState { now, done, missed, next }

class FeedCardModel {
  final int round;
  final DateTime time;
  final double quantity;
  final double cost;

  final FeedState state;

  final double riskPercent;
  final double fcrImpact;

  final String insight;

  final double expectedGrowthValue;

  final int streak;

  FeedCardModel({
    required this.round,
    required this.time,
    required this.quantity,
    required this.cost,
    required this.state,
    required this.riskPercent,
    required this.fcrImpact,
    required this.insight,
    required this.expectedGrowthValue,
    required this.streak,
  });
}

class FeedCard extends StatelessWidget {
  final FeedCardModel model;
  final VoidCallback? onMarkFed;
  final VoidCallback? onEdit;

  const FeedCard({
    super.key,
    required this.model,
    this.onMarkFed,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isNow = model.state == FeedState.now;
    final isDone = model.state == FeedState.done;
    final isMissed = model.state == FeedState.missed;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackground(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor(), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildFeedInfo(),
          const SizedBox(height: 12),
          if (isNow || isMissed) _buildRisk(),
          const SizedBox(height: 12),
          if (!isDone) _buildInsight(),
          const SizedBox(height: 12),
          if (isNow) _buildActions(),
          if (isDone) _buildDoneState(),
          if (isMissed) _buildMissedState(),
          const SizedBox(height: 12),
          _buildReward(),
        ],
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Round ${model.round} • ${DateFormat('hh:mm a').format(model.time)}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        _buildStateBadge(),
      ],
    );
  }

  Widget _buildStateBadge() {
    String text;
    Color color;

    switch (model.state) {
      case FeedState.now:
        text = "NOW";
        color = Colors.green;
        break;
      case FeedState.done:
        text = "DONE";
        color = Colors.grey;
        break;
      case FeedState.missed:
        text = "MISSED";
        color = Colors.red;
        break;
      case FeedState.next:
        text = "NEXT";
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  // ---------------- FEED INFO ----------------

  Widget _buildFeedInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${model.quantity.toStringAsFixed(1)} kg  (₹${model.cost.toStringAsFixed(0)})",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          "💰 Expected Growth: +₹${model.expectedGrowthValue.toStringAsFixed(0)}",
          style:
              const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ---------------- RISK ----------------

  Widget _buildRisk() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "⚠️ Risk: Growth -${model.riskPercent}% | FCR +${model.fcrImpact}",
        style: const TextStyle(
            color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  // ---------------- INSIGHT ----------------

  Widget _buildInsight() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text("🧠 ${model.insight}", style: const TextStyle(fontSize: 13)),
    );
  }

  // ---------------- ACTIONS ----------------

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onMarkFed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text("MARK AS FED",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_note_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
          ),
        )
      ],
    );
  }

  // ---------------- DONE ----------------

  Widget _buildDoneState() {
    return const Text(
      "✅ Feed completed • Growth on track",
      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
    );
  }

  // ---------------- MISSED ----------------

  Widget _buildMissedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("❌ Missed feed",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Adjust Plan"),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () {},
              child: const Text("Skip"),
            ),
          ],
        )
      ],
    );
  }

  // ---------------- REWARD ----------------

  Widget _buildReward() {
    return Text(
      "🔥 Streak: ${model.streak} feeds",
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    );
  }

  // ---------------- STYLING ----------------

  Color _getBackground() {
    switch (model.state) {
      case FeedState.now:
        return Colors.green.withOpacity(0.05);
      case FeedState.done:
        return Colors.grey.shade50;
      case FeedState.missed:
        return Colors.red.withOpacity(0.05);
      case FeedState.next:
        return Colors.white;
    }
  }

  Color _getBorderColor() {
    switch (model.state) {
      case FeedState.now:
        return Colors.green;
      case FeedState.done:
        return Colors.grey.shade300;
      case FeedState.missed:
        return Colors.red;
      case FeedState.next:
        return Colors.grey.shade200;
    }
  }
}
