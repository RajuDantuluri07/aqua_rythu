import 'package:flutter/material.dart';

class SupplementItem {
  final String name;
  final String unit;
  final double quantity;
  final bool isMandatory;

  SupplementItem({
    required this.name,
    required this.unit,
    required this.quantity,
    this.isMandatory = true,
  });
}

class SupplementChip extends StatelessWidget {
  final SupplementItem item;

  const SupplementChip({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isMandatory) ...[
            const Icon(
              Icons.warning_amber_rounded,
              size: 12,
              color: Colors.orange,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              "${item.name} ${item.quantity.toStringAsFixed(1)}${item.unit}",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
