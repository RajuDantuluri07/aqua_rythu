import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/server_time_provider.dart';

/// Banner widget to show time synchronization status
/// Displays when device time is being used instead of server time
class TimeSyncBanner extends ConsumerWidget {
  const TimeSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeState = ref.watch(serverTimeProvider);

    // Only show banner if there's an error (using device time fallback)
    if (timeState.errorMessage == null || timeState.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              timeState.errorMessage!,
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(serverTimeProvider.notifier).refresh(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper widget to show DOC with loading state
/// Displays skeleton loader while server time is being fetched
class DocDisplay extends ConsumerWidget {
  final DateTime stockingDate;
  final TextStyle? style;
  final String? prefix;

  const DocDisplay({
    super.key,
    required this.stockingDate,
    this.style,
    this.prefix,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeState = ref.watch(serverTimeProvider);

    if (timeState.isLoading || timeState.time == null) {
      // Show skeleton loader while fetching server time
      return Container(
        width: 40,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    // Calculate DOC using server time
    final todayUtc = DateTime.utc(
      timeState.time!.year,
      timeState.time!.month,
      timeState.time!.day,
    );
    final stockingUtc = DateTime.utc(
      stockingDate.year,
      stockingDate.month,
      stockingDate.day,
    );
    final doc = todayUtc.difference(stockingUtc).inDays + 1;
    final displayDoc = doc > 0 ? doc : 1;

    return Text(
      '${prefix ?? ''}Day $displayDoc',
      style: style,
    );
  }
}
