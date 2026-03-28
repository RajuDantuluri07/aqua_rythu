import 'package:flutter/material.dart';

class MixItemRow extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController doseController;
  final String unit;
  final ValueChanged<String?> onUnitChanged;
  final VoidCallback onDelete;

  const MixItemRow({
    super.key,
    required this.nameController,
    required this.doseController,
    required this.unit,
    required this.onUnitChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: "Item",
                filled: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: doseController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Dose",
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: unit,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: "ml", child: Text("ml")),
              DropdownMenuItem(value: "g", child: Text("g")),
              DropdownMenuItem(value: "kg", child: Text("kg")),
              DropdownMenuItem(value: "L", child: Text("L")),
            ],
            onChanged: onUnitChanged,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDelete,
          )
        ],
      ),
    );
  }
}
