import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_provider.dart';
import 'upgrade_insight_provider.dart';

enum _BillingCycle { perCrop, yearly }

class UpgradeToProScreen extends ConsumerStatefulWidget {
  const UpgradeToProScreen({super.key});

  @override
  ConsumerState<UpgradeToProScreen> createState() => _State();
}

class _State extends ConsumerState<UpgradeToProScreen> {
  _BillingCycle _cycle = _BillingCycle.perCrop;

  @override
  void initState() {
    super.initState();
    UpgradeMetrics.track('paywall_view', {'screen': 'upgrade_to_pro'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            children: [
              const Text(
                'Upgrade Your Farm Intelligence',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 20),
              _basicCard(),
              const SizedBox(height: 16),
              _proCard(),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Farmers typically recover cost in 7–10 days',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _billingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAECEF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn('Per Crop', _cycle == _BillingCycle.perCrop,
              () => setState(() => _cycle = _BillingCycle.perCrop)),
          _toggleBtn('Yearly (Save more)', _cycle == _BillingCycle.yearly,
              () => setState(() => _cycle = _BillingCycle.yearly)),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF16A34A) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF111111),
          ),
        ),
      ),
    );
  }

  Widget _basicCard() {
    return Opacity(
      opacity: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BASIC (Free)',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111)),
            ),
            const SizedBox(height: 16),
            _includedList(const [
              'Feed schedule (DOC based)',
              'Manual tray logging',
              'Sampling (ABW)',
              'Basic dashboard',
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5E7EB),
                  foregroundColor: const Color(0xFF111111),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Continue Free',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proCard() {
    final sub = ref.watch(subscriptionProvider);
    final isPerCrop = _cycle == _BillingCycle.perCrop;

    final priceMain = isPerCrop ? '₹999' : '₹2999';
    final priceStrike = isPerCrop ? '₹2000' : '';
    final priceUnit = isPerCrop ? 'per crop' : 'per year (~₹250/month)';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF16A34A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🔥 Most Popular',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF15803D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'PRO',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111)),
          ),
          const SizedBox(height: 12),
          _billingToggle(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceMain,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              if (priceStrike.isNotEmpty) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    priceStrike,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Color(0xFF888888),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            priceUnit,
            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Save ₹5,000–₹20,000 per crop',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF065F46),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _includedList(const [
            'Smart feed engine (tray + growth + FCR)',
            'Feed savings with ₹ impact',
            'FCR improvement',
            'Growth intelligence',
            'Multi-pond comparison',
            'Full crop report (PDF)',
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: sub.isLoading
                  ? null
                  : () =>
                      ref.read(subscriptionProvider.notifier).upgradeToPro(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: sub.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Start Saving Feed Now',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _includedList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_rounded,
                        size: 16, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF111111)),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
