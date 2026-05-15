import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/feed_savings_service.dart';
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
    if (savingsResult.displayType.toString() ==
        SavingsDisplayType.hide.toString()) {
      return const SizedBox.shrink();
    }

    final isOverfeed =
        savingsResult.displayType.toString() ==
        SavingsDisplayType.overfeed.toString();
    Color savingsColor =
        isOverfeed ? const Color(0xFFF59E0B) : _getSavingsColor(savingsResult.moneySaved.abs());

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

            if (isOverfeed)
              Icon(Icons.warning_amber_rounded, color: savingsColor, size: 16)
            else if (savingsResult.displayType.toString() ==
                    SavingsDisplayType.showSavings.toString() &&
                !isPro)
              Icon(Icons.lock_rounded, color: savingsColor, size: 16)
            else if (savingsResult.displayType.toString() !=
                SavingsDisplayType.partialData.toString())
              Icon(Icons.trending_up_rounded, color: savingsColor, size: 16),
          ],
        ),
      ),
    );
  }

  String _getDisplayText(dynamic result, bool isPro) {
    final type = result.displayType.toString();
    if (type == SavingsDisplayType.overfeed.toString()) {
      return result.displayMessage ?? 'Overfeeding detected this cycle';
    }
    if (type == SavingsDisplayType.showSavings.toString()) {
      if (isPro) {
        return result.displayMessage ?? 'You saved ₹0 in feed so far';
      }
      return 'Unlock your feed savings — Upgrade to PRO';
    }
    if (type == SavingsDisplayType.partialData.toString()) {
      return result.displayMessage ?? 'Start using trays to track savings';
    }
    if (type == SavingsDisplayType.noData.toString()) {
      return result.displayMessage ?? 'No feed data logged yet';
    }
    return '';
  }

  Color _getSavingsColor(double moneySaved) {
    final colorHex = FeedSavingsService.getSavingsColor(moneySaved);
    return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  }

  IconData _getSavingsIcon(dynamic displayType) {
    final type = displayType.toString();
    if (type == SavingsDisplayType.overfeed.toString()) {
      return Icons.warning_amber_rounded;
    }
    if (type == SavingsDisplayType.showSavings.toString()) {
      return Icons.savings_rounded;
    }
    if (type == SavingsDisplayType.partialData.toString()) {
      return Icons.info_outline_rounded;
    }
    if (type == SavingsDisplayType.noData.toString()) {
      return Icons.feed_outlined;
    }
    return Icons.savings_rounded;
  }

}
