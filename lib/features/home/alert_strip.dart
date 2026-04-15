import 'package:flutter/material.dart';
import 'home_view_model.dart';

/// Displays the single highest-priority alert computed by HomeBuilder.
/// Zero logic here — purely a display widget.
class AlertStrip extends StatelessWidget {
  final AlertData data;

  const AlertStrip({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: data.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.border),
      ),
      child: Row(
        children: [
          Text(data.icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: data.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
