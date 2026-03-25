import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'feed_plan_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/logger.dart';

class FeedScheduleScreen extends ConsumerWidget {
  final String pondId;
  const FeedScheduleScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planMap = ref.watch(feedPlanProvider);
    final plan = planMap[pondId];
    final days = plan?.days ?? [];

    final farmState = ref.watch(farmProvider);
    String pondName = pondId;
    for (var farm in farmState.farms) {
      try {
        final pond = farm.ponds.firstWhere((p) => p.id == pondId);
        pondName = pond.name;
        break;
      } catch (e, stack) {
        AppLogger.error("Error finding pond in FeedScheduleScreen", e, stack);
      }
    }

    // Assuming DOC 1-25 or similar based on days list
    final docRange = days.isEmpty ? "" : "DOC ${days.first.doc}-${days.last.doc}";

    return Scaffold(
      backgroundColor: AppColors.cardBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF475569)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Feed Schedule",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "$pondName • $docRange",
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.orange),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: days.isEmpty
          ? const Center(child: Text("No plan generated yet."))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  // Main Table Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.rBase),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        _buildTableHeader(),
                        // Data Rows (Limited to showing first 9 and last 1 for ellipsis effect как в картинке)
                        if (days.length > 10) ...[
                          ...days.take(9).map((d) => _FeedRow(pondId: pondId, day: d)),
                          _buildEllipsisRow(days.length),
                          _FeedRow(pondId: pondId, day: days.last),
                        ] else
                          ...days.map((d) => _FeedRow(pondId: pondId, day: d)),
                      ],
                    ),
                  ),
                  AppSpacing.hXl,

                  // Total Summary Card
                  _buildTotalSummaryCard(plan?.totalProjected ?? 0),
                  SizedBox(height: AppSpacing.hXxl * 3), // Spacing for bottom button
                ],
              ),
            ),
      bottomSheet: _buildSaveButton(context, ref),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFB),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: _HeaderCell("DOC")),
          Expanded(flex: 3, child: _HeaderCell("R1 (KG)")),
          Expanded(flex: 3, child: _HeaderCell("R2 (KG)")),
          Expanded(flex: 3, child: _HeaderCell("R3 (KG)")),
          Expanded(flex: 3, child: _HeaderCell("R4 (KG)")),
          Expanded(flex: 2, child: _HeaderCell("TOTAL", align: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildEllipsisRow(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
      alignment: Alignment.center,
      child: Text(
        "... Days 10 to ${count - 1} ...",
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
      ),
    );
  }

  Widget _buildTotalSummaryCard(double total) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(AppRadius.rBase),
        border: Border.all(color: const Color(0xFFFFEED9)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.rs),
            ),
            child: const Icon(Icons.bar_chart, color: Colors.orange, size: 24),
          ),
          AppSpacing.wBase,
          const Text(
            "Total Projected Feed",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          Text(
            "${total.toStringAsFixed(1)} kg",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: AppSpacing.base, right: AppSpacing.base, bottom: AppSpacing.xl, top: AppSpacing.m),
      child: ElevatedButton.icon(
        onPressed: () {
          ref.read(feedPlanProvider.notifier).savePlan(pondId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Feed Schedule Saved Successfully")),
          );
        },
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text(
          "Save Schedule",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.rm)),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;
  const _HeaderCell(this.label, {this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _FeedRow extends ConsumerStatefulWidget {
  final String pondId;
  final FeedDayPlan day;
  const _FeedRow({required this.pondId, required this.day});

  @override
  ConsumerState<_FeedRow> createState() => _FeedRowState();
}

class _FeedRowState extends ConsumerState<_FeedRow> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.day.rounds
        .map((r) => TextEditingController(text: r.toStringAsFixed(1)))
        .toList();
  }

  @override
  void didUpdateWidget(_FeedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) {
      for (int i = 0; i < _controllers.length && i < widget.day.rounds.length; i++) {
        _controllers[i].text = widget.day.rounds[i].toStringAsFixed(1);
      }
    }
  }

  void _onChanged(int index) {
    final val = double.tryParse(_controllers[index].text) ?? 0;
    ref.read(feedPlanProvider.notifier).updateFeed(
          pondId: widget.pondId,
          doc: widget.day.doc,
          roundIndex: index,
          qty: val,
        );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-watch for total updates if needed, but since updateFeed triggers state change,
    // and this is a ConsumerStatefulWidget, it should work fine if we watch something or if the parent rebuilds.
    // However, for efficiency, widget.day is already updated in the provider since it's a reference (mostly).
    // Let's ensure the total updates accurately.
    final currentDay = ref.watch(feedPlanProvider)[widget.pondId]?.days.firstWhere((d) => d.doc == widget.day.doc);
    final total = currentDay?.total ?? 0;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "${widget.day.doc}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Dynamically build cells based on controllers (rounds)
          for (int i = 0; i < _controllers.length; i++)
             _buildInputCell(_controllers[i], i),
          Expanded(
            flex: 2,
            child: Text(
              total.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCell(TextEditingController controller, int index) {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            onChanged: (val) => _onChanged(index),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}