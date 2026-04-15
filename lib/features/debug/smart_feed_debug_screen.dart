import 'package:flutter/material.dart';
import '../../models/feed_result.dart';

class SmartFeedDebugScreen extends StatelessWidget {
  final FeedResult data;

  const SmartFeedDebugScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text("Smart Feed Debug Dashboard"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _feedSummaryCard(),
            const SizedBox(height: 16),
            _feedSourceCard(),
            const SizedBox(height: 16),
            _feedBreakdownCard(),
            const SizedBox(height: 16),
            _smartFactorsCard(),
            const SizedBox(height: 16),
            _explanationCard(),
            const SizedBox(height: 16),
            _recommendationCard(), // 🔥 NEW
            const SizedBox(height: 16),
            _debugLogs(),
          ],
        ),
      ),
    );
  }

  // 🔷 1. Feed Summary
  Widget _feedSummaryCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Feed Recommendation",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text("🐟 ${data.finalFeed.toStringAsFixed(2)} kg",
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            "📉 Adjusted from: ${data.docFeed.toStringAsFixed(2)} kg",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            "⚙️ Mode: ${data.source == FeedSource.doc ? "DOC" : "SMART (Biomass + FCR)"}",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // 🔷 2. Feed Source
  Widget _feedSourceCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Feed Source",
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              _sourceChip("DOC", data.source == FeedSource.doc),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    height: 2,
                    color: Colors.grey[300],
                  ),
                ),
              ),
              _sourceChip("BIOMASS", data.source == FeedSource.biomass),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Active: ${data.source == FeedSource.doc ? "DOC" : "BIOMASS"}",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            "Reason: ${data.source == FeedSource.biomass ? "Sampling available (ABW: 12.5g)" : "Sampling not available"}",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 🔷 3. Breakdown
  Widget _feedBreakdownCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Feed Breakdown",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          _row("DOC Feed", data.docFeed),
          if (data.biomassFeed != null) ...[
            _row("Biomass Feed", data.biomassFeed!),
            const SizedBox(height: 4),
          ],
          if (data.fcrFactor != null) ...[
            _row("FCR Adjustment",
                (data.docFeed - (data.biomassFeed ?? data.docFeed))),
            const SizedBox(height: 4),
          ],
          Divider(color: Colors.grey[300]),
          _row("Final Feed", data.finalFeed, bold: true, highlight: true),
        ],
      ),
    );
  }

  // 🔷 4. Smart Factors
  Widget _smartFactorsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Smart Factors",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          _factor("FCR Factor", data.fcrFactor),
          _factor("Tray Factor", data.trayFactor),
          _factor("Growth Factor", data.growthFactor),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text("Confidence Score: ",
                    style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  "${(data.confidenceScore * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _factor(String name, double? value) {
    if (value == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text("🟡 $name: ",
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text("Not Available",
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      );
    }

    String emoji;
    Color color;

    if (value > 1.02) {
      emoji = "🟢";
      color = Colors.green;
    } else if (value < 0.98) {
      emoji = "🔴";
      color = Colors.red;
    } else {
      emoji = "🔵";
      color = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$emoji $name: ",
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value.toStringAsFixed(2),
            style:
                TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
          )
        ],
      ),
    );
  }

  // 🔷 5. Explanation
  Widget _explanationCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Why this feed?",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Text(
            data.explanation,
            style: TextStyle(
              color: Colors.grey[800],
              height: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Recommendations:",
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: Colors.amber)),
                SizedBox(height: 8),
                Text("→ Monitor tray after next feed",
                    style: TextStyle(fontSize: 12)),
                SizedBox(height: 4),
                Text("→ Consider reducing by 0.5 kg tomorrow",
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 🔷 6. Recommendations
  Widget _recommendationCard() {
    if (data.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Next Actions",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          ...data.recommendations.map((recommendation) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("→ ",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: TextStyle(
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // 🔷 7. Debug Logs
  Widget _debugLogs() {
    return ExpansionTile(
      title: const Text("Debug Logs",
          style: TextStyle(fontWeight: FontWeight.w600)),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _logEntry("FEED_SOURCE", data.source.name.toUpperCase()),
              _logEntry("DOC_FEED", data.docFeed.toStringAsFixed(2)),
              _logEntry("BIOMASS_FEED",
                  data.biomassFeed?.toStringAsFixed(2) ?? "N/A"),
              _logEntry("FCR_FACTOR",
                  data.fcrFactor?.toStringAsFixed(2) ?? "N/A"),
              _logEntry("TRAY_FACTOR",
                  data.trayFactor?.toStringAsFixed(2) ?? "N/A"),
              _logEntry("GROWTH_FACTOR",
                  data.growthFactor?.toStringAsFixed(2) ?? "N/A"),
              _logEntry("FINAL_FEED", data.finalFeed.toStringAsFixed(2)),
              _logEntry("CONFIDENCE_SCORE",
                  (data.confidenceScore * 100).toStringAsFixed(1) + "%"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logEntry(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key,
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'monospace', fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  fontSize: 11)),
        ],
      ),
    );
  }

  // 🔳 Common Card UI
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _row(String label, double value,
      {bool bold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: highlight ? Colors.black : Colors.grey[700],
              )),
          Text(
            "${value.toStringAsFixed(2)} kg",
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.green : Colors.black,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
