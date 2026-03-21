import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tray_provider.dart';
import 'tray_model.dart';
import '../../shared/constants/tray_status.dart';

class TrayLogScreen extends ConsumerStatefulWidget {
  final String pondId;
  final int round;
  const TrayLogScreen({super.key, required this.pondId, required this.round});

  @override
  ConsumerState<TrayLogScreen> createState() => _TrayLogScreenState();
}

class _TrayLogScreenState extends ConsumerState<TrayLogScreen> {
  int numberOfTrays = 4;
  late List<TrayFill> trayStatuses;

  @override
  void initState() {
    super.initState();
    _resetTrays();
  }

  void _resetTrays() {
    trayStatuses = List.generate(numberOfTrays, (_) => TrayFill.empty);
  }

  void _save() {
  final log = TrayLog(
  pondId: widget.pondId,
  time: DateTime.now(),
  trays: trayStatuses,
);

    ref.read(trayProvider(widget.pondId).notifier).addTrayLog(log);

    // Pass back a simple summary for the dashboard UI (optional)
    Navigator.pop(context, "Logged ${numberOfTrays} trays");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Round ${widget.round} Tray Check")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // TRAY COUNT SELECTOR
            const Text(
              "How many trays checked?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [2, 4, 6].map((count) {
                final isSelected = numberOfTrays == count;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text("$count Trays"),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          numberOfTrays = count;
                          _resetTrays();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            const Divider(),
            
            Expanded(
              child: ListView.builder(
                itemCount: numberOfTrays,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tray ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Wrap(
                            spacing: 8,
                            children: [
                              _statusChip(index, TrayFill.empty, "Empty", Colors.green),
                              _statusChip(index, TrayFill.mostlyEaten, "Mostly", Colors.lightGreen),
                              _statusChip(index, TrayFill.halfEaten, "Half", Colors.orange),
                              _statusChip(index, TrayFill.untouched, "Full", Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ), 
                  );
                },
              ),
            ),

            /// SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F9D55),
                ),
                child: const Text("Save Tray Check"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(int index, TrayFill status, String label, Color color) {
    final isSelected = trayStatuses[index] == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            trayStatuses[index] = status;
          });
        }
      },
      avatar: isSelected ? Icon(Icons.check, size: 16, color: color) : null,
    );
  }
}