import 'package:flutter/material.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';

class SupplementChip extends StatelessWidget {
  final SupplementItem item;

  const SupplementChip({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        "${item.name}: ${item.quantity.toStringAsFixed(1)}${item.unit}",
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.indigo,
        ),
      ),
      backgroundColor: Colors.indigo.shade50,
      side: BorderSide(color: Colors.indigo.shade100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
