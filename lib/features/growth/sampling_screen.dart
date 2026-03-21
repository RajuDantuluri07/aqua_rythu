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
  final _weightController = TextEditingController();
  final _countController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _save() {
    final weight = double.tryParse(_weightController.text);
    final count = int.tryParse(_countController.text);

    if (weight == null || count == null || weight <= 0 || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid positive numbers")),
      );
      return;
    }

    final doc = ref.read(docProvider(widget.pondId));

    ref.read(growthProvider(widget.pondId).notifier).updateStats(
          avgWeight: weight,
          totalCount: count,
          doc: doc,
        );

    _weightController.clear();
    _countController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sampling data saved successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(docProvider(widget.pondId));
    final growthState = ref.watch(growthProvider(widget.pondId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sampling"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Current DOC", style: TextStyle(color: Colors.grey)),
                        Text("$doc days", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Last ABW", style: TextStyle(color: Colors.grey)),
                        Text("${growthState.avgWeight} g", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text("Enter New Sampling Data",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Average Body Weight (ABW)",
                        hintText: "e.g. 15.5",
                        suffixText: "g",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Estimated Survival Count",
                        hintText: "e.g. 95000",
                        suffixText: "PL",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF1F9D55),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Update Growth Stats"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            const Text("History",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            
            if (growthState.logs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      const Text("No sampling history yet",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: growthState.logs.length,
                itemBuilder: (context, index) {
                  final log = growthState.logs[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                        "DOC ${log.doc} • ${log.date.day}/${log.date.month}",
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${log.avgWeight} g",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue)),
                        Text("${log.count} PL",
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                },
              )
          ],
        ),
      ),
    );
  }
}