import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/feed/feed_savings_service.dart';
import '../../../features/upgrade/subscription_provider.dart';

/// Feed Savings Card for Dashboard
/// Shows money saved through optimized feeding
class FeedSavingsCard extends ConsumerWidget {
  final dynamic savingsResult;
  final VoidCallback? onTap;

  const FeedSavingsCard({
    super.key,
    required this.savingsResult,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(subscriptionProvider).isPro;

    // Don't show for HIDE type
    if (savingsResult.displayType.toString() == 'hide') {
      return const SizedBox.shrink();
    }

    Color savingsColor = _getSavingsColor(savingsResult.moneySaved);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: savingsColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: savingsColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: savingsColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getSavingsIcon(savingsResult.displayType),
                color: savingsColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDisplayText(savingsResult, isPro),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: savingsColor,
                      height: 1.3,
                    ),
                  ),
                  if (savingsResult.displayType.toString() ==
                      'partialData') ...[
                    const SizedBox(height: 2),
                    Text(
                      'Add tray checks to unlock savings tracking',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Lock icon for FREE users or arrow for PRO
            if (savingsResult.displayType.toString() == 'showSavings' && !isPro)
              Icon(
                Icons.lock_rounded,
                color: savingsColor,
                size: 16,
              )
            else if (savingsResult.displayType.toString() != 'partialData')
              Icon(
                Icons.trending_up_rounded,
                color: savingsColor,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  String _getDisplayText(dynamic result, bool isPro) {
    switch (result.displayType.toString()) {
      case 'showSavings':
        if (isPro) {
          return result.displayMessage ?? 'You saved ₹0 in feed so far';
        } else {
          // FREE users: never expose the actual rupee figure. The card is a
          // teaser — the real number lives behind PRO.
          return 'Unlock your feed savings — Upgrade to PRO';
        }
      case 'partialData':
        return result.displayMessage ?? 'Start using trays to track savings';
      case 'noData':
        return result.displayMessage ?? 'No feed data logged yet';
      case 'hide':
        return '';
    }
    return '';
  }

  Color _getSavingsColor(double moneySaved) {
    final colorHex = FeedSavingsService.getSavingsColor(moneySaved);
    return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  }

  IconData _getSavingsIcon(dynamic displayType) {
    switch (displayType.toString()) {
      case 'showSavings':
        return Icons.savings_rounded;
      case 'partialData':
        return Icons.info_outline_rounded;
      case 'noData':
        return Icons.feed_outlined;
      case 'hide':
        return Icons.savings_rounded;
    }
    return Icons.savings_rounded;
  }

}
