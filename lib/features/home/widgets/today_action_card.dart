import 'package:flutter/material.dart';

class TodayActionCard extends StatelessWidget {
  final String title;
  final String description;
  final String priority;
  final IconData icon;
  final VoidCallback? onTap;

  const TodayActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.priority,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color iconColor;
    Color iconBgColor;

    switch (priority) {
      case 'critical':
        borderColor = const Color(0xFFE53935);
        iconColor = const Color(0xFFE53935);
        iconBgColor = const Color(0xFFE53935).withOpacity(0.1);
        break;
      case 'warning':
        borderColor = const Color(0xFFFFC107);
        iconColor = const Color(0xFFFFC107);
        iconBgColor = const Color(0xFFFFC107).withOpacity(0.1);
        break;
      case 'success':
        borderColor = Colors.transparent;
        iconColor = Colors.grey;
        iconBgColor = Colors.grey.withOpacity(0.1);
        break;
      default:
        borderColor = const Color(0xFF006A3A);
        iconColor = const Color(0xFF006A3A);
        iconBgColor = const Color(0xFF006A3A).withOpacity(0.1);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: priority == 'success'
              ? Colors.grey.withOpacity(0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 4,
            ),
            top: BorderSide(
              color: borderColor.withOpacity(0.3),
            ),
            right: BorderSide(
              color: borderColor.withOpacity(0.3),
            ),
            bottom: BorderSide(
              color: borderColor.withOpacity(0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: priority == 'success'
                          ? Colors.grey[600]
                          : const Color(0xFF1A1C1C),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3E4A40),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (priority != 'success')
              Icon(
                Icons.chevron_right,
                color: const Color(0xFF3E4A40),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
