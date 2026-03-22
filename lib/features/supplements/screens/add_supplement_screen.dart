import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supplement_provider.dart';
import '../widgets/section_title.dart';
import '../widgets/input_field.dart';
import '../widgets/chip_selector.dart';
import '../widgets/mix_item_row.dart';

class AddSupplementScreen extends ConsumerStatefulWidget {
  final Supplement? supplement;

  const AddSupplementScreen({super.key, this.supplement});

  @override
  ConsumerState<AddSupplementScreen> createState() => _AddSupplementScreenState();
}

class _AddSupplementScreenState extends ConsumerState<AddSupplementScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController startDocController = TextEditingController();
  final TextEditingController endDocController = TextEditingController();

  List<String> feedingTimes = [];
  List<Map<String, dynamic>> items = [
    {
      "name": TextEditingController(),
      "dose": TextEditingController(),
      "unit": "ml",
    }
  ];

  @override
  void initState() {
    super.initState();
    if (widget.supplement != null) {
      final s = widget.supplement!;
      nameController.text = s.name;
      startDocController.text = s.startDoc.toString();
      endDocController.text = s.endDoc.toString();
      feedingTimes = List.from(s.feedingTimes);

      items = s.items.map((item) {
        return {
          "name": TextEditingController(text: item.name),
          "dose": TextEditingController(text: item.dosePerKg.toString()),
          "unit": item.unit,
        };
      }).toList();
    }
  }

  void toggleFeeding(String value) {
    setState(() {
      if (feedingTimes.contains(value)) {
        feedingTimes.remove(value);
      } else {
        feedingTimes.add(value);
      }
    });
  }

  void addItem() {
    setState(() {
      items.add({
        "name": TextEditingController(),
        "dose": TextEditingController(),
        "unit": "g",
      });
    });
  }

  void removeItem(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  bool get isValid {
    return nameController.text.isNotEmpty &&
        startDocController.text.isNotEmpty &&
        endDocController.text.isNotEmpty &&
        feedingTimes.isNotEmpty &&
        items.every((e) =>
            (e["name"] as TextEditingController).text.isNotEmpty &&
            (e["dose"] as TextEditingController).text.isNotEmpty &&
            double.tryParse((e["dose"] as TextEditingController).text) != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.supplement == null ? "Add Supplement" : "Edit Supplement")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BASIC INFO
              const SectionTitle("Basic Info"),
              InputField(controller: nameController, hint: "Name"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputField(
                      controller: startDocController,
                      hint: "Start DOC",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputField(
                      controller: endDocController,
                      hint: "End DOC",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // FEEDING SETUP
              const SectionTitle("Feeding Setup"),
              Wrap(
                spacing: 10,
                children: ["Morning", "Noon", "Evening", "Night"]
                    .map((e) => ChipSelector(
                          label: e,
                          selected: feedingTimes.contains(e),
                          onTap: () => toggleFeeding(e),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 20),

              // MIX ITEMS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionTitle("Mix Items"),
                  TextButton(
                    onPressed: addItem,
                    child: const Text("+ Add"),
                  )
                ],
              ),

              Column(
                children: List.generate(items.length, (index) {
                  return MixItemRow(
                    nameController: items[index]["name"] as TextEditingController,
                    doseController: items[index]["dose"] as TextEditingController,
                    unit: items[index]["unit"] as String,
                    onUnitChanged: (val) {
                      if (val != null) {
                        setState(() {
                          items[index]["unit"] = val;
                        });
                      }
                    },
                    onDelete: () => removeItem(index),
                  );
                }),
              ),

              const SizedBox(height: 30),

              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isValid
    ? () {
        final itemsList = items
            .map((e) => SupplementItem(
                  name: e["name"]!.text,
                  dosePerKg: double.parse(e["dose"]!.text),
                  unit: e["unit"] as String,
                ))
            .toList();

        final supplement = Supplement(
          id: widget.supplement?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: nameController.text,
          startDoc: int.parse(startDocController.text),
          endDoc: int.parse(endDocController.text),
          feedQty: 1.0, // Default to per-kg rate since UI field is removed
          feedingTimes: feedingTimes,
          items: itemsList,
        );

        // SAVE TO PROVIDER
        if (widget.supplement == null) {
          ref.read(supplementProvider.notifier).addSupplement(supplement);
        } else {
          ref.read(supplementProvider.notifier).editSupplement(supplement);
        }

        Navigator.pop(context);
      }
    : null,
                  child: const Text("Save"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}