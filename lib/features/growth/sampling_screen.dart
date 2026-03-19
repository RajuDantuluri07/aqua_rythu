import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'growth_provider.dart';

class SamplingScreen extends ConsumerStatefulWidget {
  final String pondId;
  const SamplingScreen({super.key, required this.pondId});

  @override
  ConsumerState<SamplingScreen> createState() => _SamplingScreenState();
}

class _SamplingScreenState extends ConsumerState<SamplingScreen> {

  final countController = TextEditingController();
  final weightController = TextEditingController();
  final survivalController = TextEditingController();

  double avgWeight = 0;
  int estimatedCount = 0;

  void _calculate() {
    final count = int.tryParse(countController.text) ?? 0;
    final weight = double.tryParse(weightController.text) ?? 0;
    final survival = double.tryParse(survivalController.text);

    setState(() {
      if (count > 0 && weight > 0) {
        avgWeight = weight / count;
      }
      if (survival != null && survival > 0) {
        estimatedCount = (100000 * (survival / 100)).toInt();
      } else {
        estimatedCount = ref.read(growthProvider(widget.pondId)).totalCount;
      }
    });
  }

  void _save() {
    if (countController.text.isEmpty || weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter all required fields")),
      );
      return;
    }

    final currentDoc = ref.read(docProvider(widget.pondId));

    // 🔥 UPDATE GLOBAL STATE
    ref.read(growthProvider(widget.pondId).notifier).updateStats(
          avgWeight: double.parse(avgWeight.toStringAsFixed(2)),
          totalCount: estimatedCount > 0 ? estimatedCount : null,
          doc: currentDoc,
        );

    // Clear inputs
    countController.clear();
    weightController.clear();
    survivalController.clear();
    setState(() {
      avgWeight = 0;
      estimatedCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sampling data saved")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(docProvider(widget.pondId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Growth Monitoring"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// HEADER
          Text(
            "${widget.pondId} • DOC $doc",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          const Text(
            "Growth Status: Normal ↗",
            style: TextStyle(color: Colors.green),
          ),

          const SizedBox(height: 16),

          /// CURRENT CARD
          _currentWeightCard(),

          const SizedBox(height: 16),

          /// INPUTS
          Row(
            children: [
              Expanded(
                child: _inputCard(
                  label: "Sample Count",
                  controller: countController,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _inputCard(
                  label: "Total Weight (g)",
                  controller: weightController,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _inputCard(
                  label: "Survival (%)",
                  controller: survivalController,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// CALCULATE BUTTON
          ElevatedButton(
            onPressed: _calculate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
            ),
            child: const Text("Calculate Avg Weight",
                style: TextStyle(color: Colors.black)),
          ),

          const SizedBox(height: 16),

          /// SUMMARY
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  "Avg Weight",
                  avgWeight == 0 ? "--" : "${avgWeight.toStringAsFixed(2)} g",
                  highlight: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryCard("Count/Kg",
                      avgWeight > 0 ? (1000 / avgWeight).toStringAsFixed(0) : "--")),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryCard(
                      "Biomass",
                      (avgWeight > 0 && estimatedCount > 0)
                          ? "${((estimatedCount * avgWeight) / 1000).toStringAsFixed(0)} kg"
                          : "--")),
            ],
          ),

          const SizedBox(height: 20),

          /// LEDGER
          _ledgerCard(),

          const SizedBox(height: 80),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text("SAVE & UPDATE GROWTH"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green,
          ),
        ),
      ),
    );
  }

  /// CURRENT CARD
  Widget _currentWeightCard() {
  final growth = ref.watch(growthProvider(widget.pondId));

  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("CURRENT AVERAGE WEIGHT"),
              Text("LIVE"),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            "${growth.avgWeight.toStringAsFixed(1)} g",
            style: const TextStyle(
                fontSize: 40, fontWeight: FontWeight.bold),
          ),

          const Divider(),

          Text("Biomass: ${growth.biomass.toStringAsFixed(0)} kg"),
        ],
      ),
    ),
  );
}

  /// LEDGER
  Widget _ledgerCard() {
    final logs = ref.watch(growthProvider(widget.pondId)).logs;
    final isEmpty = logs.isEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isEmpty
            ? Column(
                children: const [
                  Icon(Icons.inbox, size: 40, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No sampling history"),
                ],
              )
            : Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("SAMPLING LEDGER",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("DOWNLOAD",
                          style: TextStyle(color: Colors.green)),
                    ],
                  ),
                  const Divider(),
                  ...logs.map((item) => _RowItem(
                        "${item.date.day}/${item.date.month}",
                        item.doc.toString(),
                        "${item.avgWeight}g",
                        item.count.toString(),
                      )),
                ],
              ),
      ),
    );
  }
}

/// LEDGER ROW
class _RowItem extends StatelessWidget {
  final String date, doc, avg, count;

  const _RowItem(this.date, this.doc, this.avg, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date),
          Text("DOC $doc"),
          Text(avg),
          Text(count),
        ],
      ),
    );
  }
}