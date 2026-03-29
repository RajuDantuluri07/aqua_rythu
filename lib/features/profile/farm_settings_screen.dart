import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'farm_settings_provider.dart';

class FarmSettingsScreen extends ConsumerStatefulWidget {
  const FarmSettingsScreen({super.key});

  @override
  ConsumerState<FarmSettingsScreen> createState() => _FarmSettingsScreenState();
}

class _FarmSettingsScreenState extends ConsumerState<FarmSettingsScreen> {
  late TextEditingController feedPriceController;
  late TextEditingController blindDaysController;
  late TextEditingController jumpThresholdController;
  late TextEditingController tray30Controller;
  late TextEditingController tray60Controller;
  late TextEditingController tray90Controller;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(farmSettingsProvider);
    feedPriceController = TextEditingController(text: settings.feedPrice.toString());
    blindDaysController = TextEditingController(text: settings.blindFeedingDays.toString());
    jumpThresholdController = TextEditingController(text: settings.feedJumpThreshold.toString());
    tray30Controller = TextEditingController(text: settings.trayCalibration30_60.toString());
    tray60Controller = TextEditingController(text: settings.trayCalibration60_90.toString());
    tray90Controller = TextEditingController(text: settings.trayCalibration90Plus.toString());
  }

  @override
  void dispose() {
    feedPriceController.dispose();
    blindDaysController.dispose();
    jumpThresholdController.dispose();
    tray30Controller.dispose();
    tray60Controller.dispose();
    tray90Controller.dispose();
    super.dispose();
  }

  void _save() async {
    try {
      final settings = ref.read(farmSettingsProvider);
      
      // Parse and validate numeric inputs
      final feedPrice = double.tryParse(feedPriceController.text) ?? settings.feedPrice;
      final blindDays = int.tryParse(blindDaysController.text) ?? settings.blindFeedingDays;
      final jumpThreshold = int.tryParse(jumpThresholdController.text) ?? settings.feedJumpThreshold;
      final tray30 = double.tryParse(tray30Controller.text) ?? settings.trayCalibration30_60;
      final tray60 = double.tryParse(tray60Controller.text) ?? settings.trayCalibration60_90;
      final tray90 = double.tryParse(tray90Controller.text) ?? settings.trayCalibration90Plus;

      await ref.read(farmSettingsProvider.notifier).saveAllSettings(
        farmType: settings.farmType,
        feedsPerDay: settings.feedsPerDay,
        feedPrice: feedPrice,
        blindFeedingDays: blindDays,
        feedJumpThreshold: jumpThreshold,
        feedTimes: settings.feedTimes,
        trayCalibration30_60: tray30,
        trayCalibration60_90: tray60,
        trayCalibration90Plus: tray90,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving settings: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(farmSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Farm Settings"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// GENERAL
          const Text("GENERAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

          const SizedBox(height: 10),

          _dropdown("Farm Type", settings.farmType, ["Semi-Intensive", "Intensive"], (v) {
            if (v != null) {
              ref.read(farmSettingsProvider.notifier).setFarmType(v);
            }
          }),

          const SizedBox(height: 10),

          _dropdown("Feeds per Day", "${settings.feedsPerDay} Feeds",
              ["2 Feeds", "3 Feeds", "4 Feeds"], (v) {
            if (v != null) {
              final count = int.parse(v.split(" ")[0]);
              ref.read(farmSettingsProvider.notifier).setFeedsPerDay(count);
            }
          }),

          const SizedBox(height: 10),

          _input("Feed Price (₹/kg)", feedPriceController),

          const SizedBox(height: 10),

          _input("Blind Feeding Duration (days)", blindDaysController),

          const SizedBox(height: 10),

          _input("Feed Jump Threshold (%)", jumpThresholdController),

          const SizedBox(height: 20),

          /// FEED TIMES
          const Text("FEED TIMES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            children: List.generate(settings.feedTimes.length, (i) {
              return _timeChip(i, settings.feedTimes);
            }),
          ),

          const SizedBox(height: 20),

          /// TRAY CALIBRATION
          const Text("TRAY CHECK CALIBRATION (% of Feed)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _input("DOC 30-60", tray30Controller)),
              const SizedBox(width: 10),
              Expanded(child: _input("DOC 60-90", tray60Controller)),
              const SizedBox(width: 10),
              Expanded(child: _input("DOC 90+", tray90Controller)),
            ],
          ),

          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text("Save Settings"),
          ),
          const SizedBox(height: 16),
          Text(
            "Settings are automatically applied to feed calculations and water quality monitoring.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            onChanged(v);
            setState(() {}); // Rebuild to reflect immediate changes
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// TIME CHIP
  Widget _timeChip(int index, List<String> feedTimes) {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (time != null) {
          final updatedTimes = List<String>.from(feedTimes);
          updatedTimes[index] = time.format(context);
          ref.read(farmSettingsProvider.notifier).setFeedTimes(updatedTimes);
          setState(() {});
        }
      },
      child: Chip(
        label: Text(feedTimes[index]),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        labelStyle: TextStyle(color: Theme.of(context).primaryColor),
      ),
    );
  }
}

