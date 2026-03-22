import 'package:flutter/material.dart';

class ChipSelector extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ChipSelector({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey),
        ),
        child: Text(label),
      ),
    );
  }
}