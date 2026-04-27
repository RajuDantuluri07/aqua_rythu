import 'package:flutter/material.dart';

class ValueStatementWidget extends StatelessWidget {
  const ValueStatementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💰 Icon + Title
          Row(
            children: [
              Icon(
                Icons.trending_down,
                color: Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "The Hidden Cost",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Value statement
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: "Farmers typically lose "),
                TextSpan(
                  text: "₹5,000–₹15,000 per crop\n",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                    fontSize: 16,
                  ),
                ),
                const TextSpan(text: "due to feed mistakes.\n\n"),
                const TextSpan(text: "PRO helps you "),
                TextSpan(
                  text: "reduce that.",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
