import 'package:flutter/material.dart';

class FarmSettingsScreen extends StatefulWidget {
  const FarmSettingsScreen({super.key});

  @override
  State<FarmSettingsScreen> createState() => _FarmSettingsScreenState();
}

class _FarmSettingsScreenState extends State<FarmSettingsScreen> {

  String farmType = "Semi-Intensive";
  String feedsPerDay = "4 Feeds";

  final feedPriceController = TextEditingController(text: "90");
  final blindDaysController = TextEditingController(text: "30");
  final jumpThresholdController = TextEditingController(text: "30");

  List<String> feedTimes = ["6 AM", "10 AM", "2 PM", "6 PM"];

  final tray30 = TextEditingController(text: "0.3");
  final tray60 = TextEditingController(text: "0.6");
  final tray90 = TextEditingController(text: "1");

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Settings saved")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// GENERAL
          const Text("GENERAL",
              style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),

          _dropdown("Farm Type", farmType,
              ["Semi-Intensive", "Intensive"], (v) {
            setState(() => farmType = v!);
          }),

          const SizedBox(height: 10),

          _dropdown("Feeds per Day", feedsPerDay,
              ["2 Feeds", "3 Feeds", "4 Feeds"], (v) {
            setState(() => feedsPerDay = v!);
          }),

          const SizedBox(height: 10),

          _input("Feed Price (₹/kg)", feedPriceController),

          const SizedBox(height: 10),

          _input("Blind Feeding Duration (days)", blindDaysController),

          const SizedBox(height: 10),

          _input("Feed Jump Threshold (%)", jumpThresholdController),

          const SizedBox(height: 20),

          /// FEED TIMES
          const Text("FEED TIMES",
              style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            children: List.generate(feedTimes.length, (i) {
              return _timeChip(i);
            }),
          ),

          const SizedBox(height: 20),

          /// TRAY CALIBRATION
          const Text("TRAY CHECK CALIBRATION (% of Feed)",
              style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _input("DOC 30-60", tray30)),
              const SizedBox(width: 10),
              Expanded(child: _input("DOC 60-90", tray60)),
              const SizedBox(width: 10),
              Expanded(child: _input("DOC 90+", tray90)),
            ],
          ),

          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text("Save Settings"),
          )
        ],
      ),
    );
  }

  /// DROPDOWN
  Widget _dropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// INPUT
  Widget _input(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// TIME CHIP
  Widget _timeChip(int index) {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (time != null) {
          setState(() {
            feedTimes[index] = time.format(context);
          });
        }
      },
      child: Chip(
        label: Text(feedTimes[index]),
      ),
    );
  }
}