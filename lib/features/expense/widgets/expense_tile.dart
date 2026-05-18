import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/expense_model.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final String? pondName;
  final VoidCallback onTap;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
    this.pondName,
  });

  @override
  Widget build(BuildContext context) {
    final cat = expense.category;
    final subtitle = _buildSubtitle();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Category icon bubble
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: cat.color, size: 22),
            ),
            const SizedBox(width: 14),

            // Label + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${_formatAmount(expense.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (pondName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    pondName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[
      DateFormat('dd MMM yyyy').format(expense.date),
    ];
    if (expense.notes != null && expense.notes!.isNotEmpty) {
      parts.add(expense.notes!);
    }
    return parts.join(' · ');
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
