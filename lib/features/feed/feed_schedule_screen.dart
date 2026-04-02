import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/logger.dart';
import 'feed_schedule_provider.dart';
class FeedScheduleScreen extends ConsumerStatefulWidget {
  final String pondId;
  const FeedScheduleScreen({super.key, required this.pondId});

  @override
  ConsumerState<FeedScheduleScreen> createState() => _FeedScheduleScreenState();
}

class _FeedScheduleScreenState extends ConsumerState<FeedScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedScheduleProvider.notifier).loadFeedSchedule(widget.pondId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final feedScheduleState = ref.watch(feedScheduleProvider);
    
    String pondName = widget.pondId;
    for (var farm in farmState.farms) {
      try {
        final pond = farm.ponds.firstWhere((p) => p.id == widget.pondId);
        pondName = pond.name;
        break;
      } catch (e, stack) {
        AppLogger.error("Error finding pond in FeedScheduleScreen", e, stack);
      }
    }

    final docRange = "DOC 1–30";

    return Scaffold(
      backgroundColor: AppColors.cardBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Feed Schedule",
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              "$pondName • $docRange",
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF22C55E), size: 24),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: feedScheduleState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : feedScheduleState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Error loading feed schedule",
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        feedScheduleState.error!,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(feedScheduleProvider.notifier).loadFeedSchedule(widget.pondId);
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildTableHeader(),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(15),
                                  bottomRight: Radius.circular(15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: feedScheduleState.days.asMap().entries.map((entry) {
                                  return _FeedRow(
                                    pondId: widget.pondId,
                                    day: entry.value,
                                    index: entry.key,
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTotalSummaryCard(feedScheduleState.totalProjectedFeed),
                            const SizedBox(height: 100), // Space for save button
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      bottomSheet: _buildSaveButton(context, feedScheduleState),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: _HeaderCell("DOC", align: TextAlign.center, isWhite: true)),
          Expanded(flex: 3, child: _HeaderCell("R1", align: TextAlign.center, isWhite: true)),
          Expanded(flex: 3, child: _HeaderCell("R2", align: TextAlign.center, isWhite: true)),
          Expanded(flex: 3, child: _HeaderCell("R3", align: TextAlign.center, isWhite: true)),
          Expanded(flex: 3, child: _HeaderCell("R4", align: TextAlign.center, isWhite: true)),
          Expanded(
              flex: 3, child: _HeaderCell("TOTAL (kg)", align: TextAlign.right, isWhite: true)),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard(double total) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rBase,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF22C55E).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: AppRadius.rs,
            ),
            child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 26),
          ),
          AppSpacing.wBase,
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total Projected Feed",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            "${total.toStringAsFixed(1)} kg",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, FeedScheduleState feedScheduleState) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(
          left: AppSpacing.base,
          right: AppSpacing.base,
          bottom: AppSpacing.xl,
          top: AppSpacing.l),
      child: feedScheduleState.isSaving
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ElevatedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(feedScheduleProvider.notifier).saveFeedSchedule(widget.pondId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Feed schedule saved successfully!"),
                        backgroundColor: Color(0xFF22C55E),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to save: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save_rounded, color: Colors.white, size: 22),
              label: const Text(
                "Save Schedule",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.rm),
                elevation: 3,
              ),
            ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;
  final bool isWhite;
  const _HeaderCell(this.label, {this.align = TextAlign.center, this.isWhite = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: TextStyle(
        color: isWhite ? Colors.white : AppColors.textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _FeedRow extends ConsumerStatefulWidget {
  final String pondId;
  final FeedDayPlan day;
  final int index;
  const _FeedRow({required this.pondId, required this.day, required this.index});

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
      for (int i = 0;
          i < _controllers.length && i < widget.day.rounds.length;
          i++) {
        // 🔒 Prevent overwriting user input while typing unless value changed externally
        // This avoids cursor jumping or "1." becoming "1.0" immediately
        final currentVal = double.tryParse(_controllers[i].text) ?? 0;
        if ((currentVal - widget.day.rounds[i]).abs() > 0.01) {
          _controllers[i].text = widget.day.rounds[i].toStringAsFixed(1);
        }
      }
    }
  }

  void _onChanged(int index) {
    final val = double.tryParse(_controllers[index].text) ?? 0;
    ref.read(feedScheduleProvider.notifier).updateFeed(widget.index, index, val);
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
    // Optimized: widget.day is already the updated object from parent
    final total = widget.day.total;
    final isEvenRow = widget.index.isEven;
    final backgroundColor = isEvenRow ? Colors.white : Color(0xFFF8FAFB);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "${widget.day.doc}",
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1E293B),
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
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          height: 44,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            onChanged: (val) => _onChanged(index),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
