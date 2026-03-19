import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'water_provider.dart';

class WaterTestScreen extends ConsumerStatefulWidget {
  final String pondId;
  const WaterTestScreen({super.key, required this.pondId});

  @override
  ConsumerState<WaterTestScreen> createState() => _WaterTestScreenState();
}

class _WaterTestScreenState extends ConsumerState<WaterTestScreen> {

  final tempController = TextEditingController();
  final salinityController = TextEditingController();
  final doController = TextEditingController();
  final phController = TextEditingController();
  final ammoniaController = TextEditingController();
  final nitriteController = TextEditingController();
  final alkalinityController = TextEditingController();

  void _save() {
    if (tempController.text.isEmpty ||
        salinityController.text.isEmpty ||
        doController.text.isEmpty ||
        phController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields")),
      );
      return;
    }

    final currentDoc = ref.read(docProvider(widget.pondId));

    // Update provider state
    ref.read(waterProvider(widget.pondId).notifier).update(
          temperature: double.tryParse(tempController.text),
          ph: double.tryParse(phController.text),
          oxygen: double.tryParse(doController.text),
          ammonia: double.tryParse(ammoniaController.text),
          doc: currentDoc,
        );

    // Clear critical fields
    tempController.clear();
    phController.clear();
    doController.clear();
    ammoniaController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Water data saved")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waterState = ref.watch(waterProvider(widget.pondId));
    final waterNotifier = ref.watch(waterProvider(widget.pondId).notifier);
    final doc = ref.watch(docProvider(widget.pondId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Water Quality Log"),
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

          Text(
            "Water Status: ${waterNotifier.status} ↗",
            style: TextStyle(
                color:
                    waterNotifier.status == "Good" ? Colors.green : Colors.orange),
          ),

          const SizedBox(height: 16),

          /// HEALTH CARD
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: Text(
              "Current values: pH ${waterState.ph}, DO ${waterState.oxygen} mg/L, Temp ${waterState.temperature}°C",
            ),
          ),

          const SizedBox(height: 20),

          /// PHYSICAL PARAMETERS
          _sectionCard(
            title: "PHYSICAL PARAMETERS",
            children: [
              Row(
                children: [
                  Expanded(child: _input("Temp (°C)", tempController)),
                  const SizedBox(width: 10),
                  Expanded(child: _input("Salinity (ppt)", salinityController)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// CHEMICAL PARAMETERS
          _sectionCard(
            title: "CHEMICAL PARAMETERS",
            children: [
              Row(
                children: [
                  Expanded(child: _input("DO (mg/L)", doController)),
                  const SizedBox(width: 10),
                  Expanded(child: _input("pH", phController)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _input("Ammonia (NH3)", ammoniaController)),
                  const SizedBox(width: 10),
                  Expanded(child: _input("Nitrite (NO2)", nitriteController)),
                ],
              ),
              const SizedBox(height: 10),
              _input("Alkalinity (ppm)", alkalinityController),
            ],
          ),

          const SizedBox(height: 20),

          /// LEDGER
          _ledgerCard(),

          const SizedBox(height: 100),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.shield),
          label: const Text("SAVE & ANALYZE WATER"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green,
          ),
        ),
      ),
    );
  }

  /// SECTION CARD
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  /// INPUT
  Widget _input(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "Enter value",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  /// LEDGER
  Widget _ledgerCard() {
    final logs = ref.watch(waterProvider(widget.pondId)).logs;
    final isEmpty = logs.isEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isEmpty
            ? Column(
                children: const [
                  Icon(Icons.waves, size: 40, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No water logs available"),
                ],
              )
            : Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("SAMPLING LEDGER",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("DOWNLOAD REPORT",
                          style: TextStyle(color: Colors.green)),
                    ],
                  ),
                  const Divider(),
                  ...logs.map((item) => _RowItem(
                        date: "${item.date.day}/${item.date.month}",
                        doc: item.doc.toString(),
                        temp: item.temperature.toString(),
                        ph: item.ph.toString(),
                        doVal: item.oxygen.toString(),
                        nh3: item.ammonia.toString(),
                      )),
                ],
              ),
      ),
    );
  }
}

/// LEDGER ROW
class _RowItem extends StatelessWidget {
  final String date, doc, temp, ph, doVal, nh3;

  const _RowItem(
      {required this.date,
      required this.doc,
      required this.temp,
      required this.ph,
      required this.doVal,
      required this.nh3});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date),
          Text("DOC $doc"),
          Text(temp),
          Text(ph),
          Text(doVal),
          Text(nh3),
        ],
      ),
    );
  }
}