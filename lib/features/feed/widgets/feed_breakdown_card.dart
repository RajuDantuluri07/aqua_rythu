import 'package:flutter/material.dart';
import '../../pond/enums/seed_type.dart';
import '../models/feed_explanation.dart';

/// Shows the seed-based feed breakdown: base → tray → smart → final.
/// Also displays the WOW savings message when overfeeding is avoided.
class FeedBreakdownCard extends StatelessWidget {
  final FeedExplanation explanation;

  const FeedBreakdownCard({super.key, required this.explanation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildBreakdownRows(context),
          _buildFinalRow(context),
          if (explanation.savingsRupees != null &&
              explanation.savingsRupees! > 0)
            _buildSavingsBanner(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isHatchery = explanation.seedType == SeedType.hatcherySmall;
    final accentColor =
        isHatchery ? const Color(0xFF2196F3) : const Color(0xFF4CAF50);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Icon(Icons.auto_graph_rounded, color: accentColor, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Feed Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'DOC ${explanation.doc}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRows(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _breakdownRow(
            label: 'Base Feed',
            value: '${explanation.baseFeed.toStringAsFixed(2)} kg',
            sublabel: explanation.isSeedTablePhase
                ? '${explanation.seedType.displayName} table · DOC ${explanation.doc}'
                : 'Fallback curve · DOC ${explanation.doc}',
            icon: Icons.set_meal_rounded,
            iconColor: Colors.blueGrey,
          ),
          const SizedBox(height: 10),
          _breakdownRow(
            label: 'Tray Adjustment',
            value: _signedPercent(explanation.trayImpact),
            sublabel: explanation.trayLabel,
            icon: Icons.grid_view_rounded,
            iconColor: _factorColor(explanation.trayImpact),
            valueColor: _factorColor(explanation.trayImpact),
          ),
          const SizedBox(height: 10),
          _breakdownRow(
            label: 'Smart Adjustment',
            value: _signedPercent(explanation.smartImpact),
            sublabel: explanation.smartLabel,
            icon: Icons.psychology_rounded,
            iconColor: _factorColor(explanation.smartImpact),
            valueColor: _factorColor(explanation.smartImpact),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalRow(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1565C0).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 10),
          const Text(
            'Final Feed Today',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1565C0),
            ),
          ),
          const Spacer(),
          Text(
            '${explanation.finalFeed.toStringAsFixed(2)} kg',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsBanner(BuildContext context) {
    final savings = explanation.savingsRupees!.round();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You saved ₹$savings today by avoiding overfeeding',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow({
    required String label,
    required String value,
    required String sublabel,
    required IconData icon,
    required Color iconColor,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  String _signedPercent(double factor) {
    final pct = (factor * 100).round();
    if (pct == 0) return '0%';
    return pct > 0 ? '+$pct%' : '$pct%';
  }

  Color _factorColor(double factor) {
    if (factor < 0) return const Color(0xFFE53935);
    if (factor > 0) return const Color(0xFF43A047);
    return Colors.grey.shade500;
  }
}
