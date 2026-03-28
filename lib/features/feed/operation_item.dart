import 'package:flutter/material.dart';

/// OPERATIONS WIDGET
class OperationItem extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const OperationItem(this.title, {this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          const CircleAvatar(child: Icon(Icons.circle)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
