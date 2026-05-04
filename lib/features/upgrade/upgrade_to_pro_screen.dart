import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aqua_rythu/core/models/subscription_model.dart';
import 'subscription_provider.dart';
import 'upgrade_insight_provider.dart';

const _screenBg = Color(0xFFF2F2F7);
const _cardBg = Color(0xFFFFFFFF);
const _accent = Color(0xFF22C55E);
const _muted = Color(0xFF64748B);
const _dark = Color(0xFF1E293B);
const _strike = Color(0xFF94A3B8);
const _toggleBg = Color(0xFFE8E8E8);
const _savingsBg = Color(0xFFECFDF5);
const _savingsText = Color(0xFF16A34A);

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
    ref.listen<SubscriptionState>(subscriptionProvider, (prev, next) {
      if (!mounted) return;
      if (next.paymentPhase == PaymentPhase.success &&
          prev?.paymentPhase != PaymentPhase.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PRO activated! Welcome to full power.'),
            backgroundColor: _accent,
          ),
        );
        Navigator.of(context).pop();
      }
    });

    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: _screenBg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(sub),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Upgrade Your Farm Intelligence',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (sub.hasPendingVerification &&
                        sub.paymentPhase != PaymentPhase.verifying)
                      _retryBanner(sub),

                    _basicCard(),
                    const SizedBox(height: 20),
                    _proCard(sub),
                    const SizedBox(height: 16),
                    const Text(
                      'Farmers typically recover cost in 7–10 days',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(SubscriptionState sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  size: 18, color: Colors.grey.shade700),
            ),
          ),
          const Spacer(),
          if (!sub.isPro)
            GestureDetector(
              onTap: sub.isLoading ? null : _handleRestore,
              child: Text(
                'RESTORE',
                style: TextStyle(
                  fontSize: 12,
                  color: sub.isLoading ? _muted.withOpacity(0.4) : _muted,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _retryBanner(SubscriptionState sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Payment captured. Tap Retry to activate PRO.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: sub.isLoading
                ? null
                : () => ref
                    .read(subscriptionProvider.notifier)
                    .retryVerification(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('RETRY',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRestore() async {
    final found =
        await ref.read(subscriptionProvider.notifier).restorePurchase();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          found
              ? 'PRO access restored successfully!'
              : 'No active subscription found for this account.',
        ),
        backgroundColor: found ? _accent : Colors.red.shade700,
      ),
    );
    if (found) Navigator.of(context).pop();
  }

  Widget _basicCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BASIC (Free)',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
          ),
          const SizedBox(height: 16),
          _featureList(const [
            '1 farm upto 3 ponds',
            'Feed schedule (DOC based)',
            'Manual tray logging',
            'Sampling (ABW)',
            'Basic dashboard',
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8E8E8),
                foregroundColor: _dark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Continue Free',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proCard(SubscriptionState sub) {
    final isPerCrop = _cycle == _BillingCycle.perCrop;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Most Popular badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _savingsBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🔥 Most Popular',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _savingsText),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'PRO',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: _dark),
          ),
          const SizedBox(height: 14),

          // Billing toggle
          _billingToggle(),
          const SizedBox(height: 16),

          // Price
          _priceRow(isPerCrop),
          const SizedBox(height: 12),

          // Savings chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _savingsBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Save ₹5,000–₹20,000 per crop',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _savingsText),
            ),
          ),
          const SizedBox(height: 16),

          _featureList(const [
            'Unlimited farms & unlimited ponds',
            'Roles (Farmer / Partner / Supervisor / Workers)',
            'Smart feed engine (tray + growth + FCR)',
            'Feed savings with ₹ impact',
            'FCR improvement',
            'Growth intelligence',
            'Multi-pond comparison',
            'Full crop report (PDF)',
          ]),
          const SizedBox(height: 20),

          if (sub.isPro) _proActiveButton() else _payButton(sub, isPerCrop),
        ],
      ),
    );
  }

  Widget _billingToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _toggleBg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _toggleChip(
            'Per Crop',
            _cycle == _BillingCycle.perCrop,
            () => setState(() => _cycle = _BillingCycle.perCrop),
          ),
          _toggleChip(
            'Yearly (Save more)',
            _cycle == _BillingCycle.yearly,
            () => setState(() => _cycle = _BillingCycle.yearly),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : _muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _priceRow(bool isPerCrop) {
    if (isPerCrop) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹999',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    height: 1),
              ),
              SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '₹2000',
                  style: TextStyle(
                    fontSize: 16,
                    color: _strike,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: _strike,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text('per crop',
              style: TextStyle(fontSize: 14, color: _muted)),
        ],
      );
    } else {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '₹2999',
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: _dark,
                height: 1),
          ),
          SizedBox(height: 2),
          Text('per year (~₹250/month)',
              style: TextStyle(fontSize: 14, color: _muted)),
        ],
      );
    }
  }

  Widget _proActiveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.workspace_premium_rounded, size: 20),
        label: const Text("You're on PRO",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent.withOpacity(0.15),
          foregroundColor: _accent,
          disabledBackgroundColor: _accent.withOpacity(0.15),
          disabledForegroundColor: _accent,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _payButton(SubscriptionState sub, bool isPerCrop) {
    const plan = PlanType.PRO;
    final busy = sub.isLoading;

    final label = switch (sub.paymentPhase) {
      PaymentPhase.creatingOrder => 'Preparing order…',
      PaymentPhase.awaitingPayment => 'Waiting for payment…',
      PaymentPhase.verifying => 'Verifying payment…',
      _ => 'Start Saving Feed Now',
    };

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: busy
            ? null
            : () {
                UpgradeMetrics.trackCtaClick(
                  source: 'upgrade_screen',
                  plan: isPerCrop ? '999_crop' : '2999_year',
                  insight: UpgradeLossInsight.simulated(),
                );
                ref
                    .read(subscriptionProvider.notifier)
                    .initiatePayment(plan);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _featureList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_rounded,
                          size: 18, color: _accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(f,
                          style: const TextStyle(
                              fontSize: 14, color: _dark, height: 1.4)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
