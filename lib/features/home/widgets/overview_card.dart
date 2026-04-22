import 'package:flutter/material.dart';

class OverviewCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> data;

  const OverviewCard({
    super.key,
    required this.title,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFBDCABD).withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00210E).withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E4A40),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...data.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                if (item['count'] is int) ...[
                  Text(
                    item['count'].toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item['status'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E4A40),
                    ),
                  ),
                ] else ...[
                  Text(
                    item['status'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1C),
                    ),
                  ),
                ],
              ],
            ),
          )),
          if (title == 'Growth overview') ...[
            const SizedBox(height: 8),
            Text(
              'Avg ratio: <span class="font-bold">0.97</span>',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3E4A40),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
