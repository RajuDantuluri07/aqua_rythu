import 'package:flutter/material.dart';

class PondCard extends StatelessWidget {
  final dynamic pond;
  final VoidCallback? onTap;

  const PondCard({
    super.key,
    required this.pond,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String status;
    Color statusColor;
    Color statusBgColor;
    Color borderColor = Colors.transparent;
    String? actionText;

    // Defensive checks for pond data
    if (pond == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.grey, size: 32),
              SizedBox(height: 8),
              Text(
                'Pond data unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determine pond status based on FCR and other metrics
    final fcr = (pond.fcr as num?)?.toDouble() ?? 0.0;
    if (fcr > 1.8) {
      status = 'CRITICAL';
      statusColor = const Color(0xFFE53935);
      statusBgColor = const Color(0xFFE53935).withOpacity(0.1);
      borderColor = const Color(0xFFE53935);
      actionText = '⚠️ Reduce feed by 10-15% today';
    } else if (fcr > 1.4) {
      status = 'WARNING';
      statusColor = const Color(0xFFA67C00);
      statusBgColor = const Color(0xFFFFC107).withOpacity(0.1);
      borderColor = const Color(0xFFFFC107);
      actionText = '⏳ Do sampling today';
    } else {
      status = 'GOOD';
      statusColor = const Color(0xFF006A3A);
      statusBgColor = const Color(0xFFBFEEC9);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: status == 'CRITICAL'
              ? const Color(0xFFE53935).withOpacity(0.03)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // Status badge
            Positioned(
              top: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (actionText != null) ...[
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          actionText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Pond content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pond.name?.toString() ?? 'Pond',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1C),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${((pond.area as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)} ac',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E4A40),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(((pond.seedCount as num?)?.toInt() ?? 0) / 100000).toStringAsFixed(1)} lac',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E4A40),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DOC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3E4A40),
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '${(pond.doc as num?)?.toInt() ?? 0}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Feed (D)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3E4A40),
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '${(pond.todayFeed ?? 0.0).toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FCR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3E4A40),
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            fcr > 0 ? fcr.toStringAsFixed(1) : '--',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
