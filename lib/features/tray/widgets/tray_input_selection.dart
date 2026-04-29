import 'package:flutter/material.dart';
import '../enums/tray_status.dart';
import 'tray_input_card.dart';

class TrayInputSelection extends StatefulWidget {
  final TrayStatus? selectedState;
  final Function(TrayStatus) onSelectionChanged;

  const TrayInputSelection({
    super.key,
    this.selectedState,
    required this.onSelectionChanged,
  });

  @override
  State<TrayInputSelection> createState() => _TrayInputSelectionState();
}

class _TrayInputSelectionState extends State<TrayInputSelection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Microcopy above component
        const Text(
          'Check tray after 2-3 hours of feeding',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),

        // 2x2 Grid of cards
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: TrayStatus.values.map((state) {
            return TrayInputCard(
              state: state,
              isSelected: widget.selectedState == state,
              onTap: () {
                setState(() {});
                widget.onSelectionChanged(state);
              },
            );
          }).toList(),
        ),

        // Dynamic hint below (only show when selected)
        if (widget.selectedState != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.selectedState!.lightColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.selectedState!.color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: widget.selectedState!.color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.selectedState!.hint,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.selectedState!.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
