import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_provider.dart';
import 'upgrade_insight_provider.dart';

const _bg = Color(0xFFFFFFFF);
const _card = Color(0xFFF8FAFC);
const _accent = Color(0xFF22C55E);
const _muted = Color(0xFF64748B);
const _listInk = Color(0xFF1E293B);
const _strike = Color(0xFF94A3B8);
const _lockRed = Color(0xFFEF4444);
const _btnFree = Color(0xFFF1F5F9);
const _toggleBg = Color(0xFFF1F5F9);

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
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 8),
              const Text(
                'Upgrade to PRO',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Make better decisions. Save feed. Increase profit.',
                style: TextStyle(fontSize: 14, color: _muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              _billingToggle(),
              const SizedBox(height: 24),
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _basicCard()),
                        const SizedBox(width: 20),
                        Expanded(child: _proCard()),
                      ],
                    )
                  : Column(
                      children: [
                        _basicCard(),
                        const SizedBox(height: 24),
                        _proCard(),
                      ],
                    ),
              const SizedBox(height: 26),
              const Center(
                child: Text(
                  'Farmers typically recover cost in 7–14 days  •  Based on feed optimization',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close_rounded,
                size: 18, color: Colors.grey.shade700),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: const Text(
            'RESTORE',
            style: TextStyle(
              fontSize: 11,
              color: _muted,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _billingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _toggleBg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn('Per Crop', _cycle == _BillingCycle.perCrop,
              () => setState(() => _cycle = _BillingCycle.perCrop)),
          _toggleBtn('For Serious Farmers', _cycle == _BillingCycle.yearly,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.black : _muted,
          ),
        ),
      ),
    );
  }

  Widget _basicCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic (Free)',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          const Text(
            '₹0',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          _includedList(const [
            'Feed schedule (DOC 1–30)',
            '1 farm / 3 ponds',
            'Manual tray logging',
            'Sampling entry (ABW)',
            'Basic dashboard',
          ]),
          _lockedList(const [
            'Smart feed adjustment',
            'FCR & savings tracking',
            'Growth intelligence',
            'Alerts & risk detection',
            'Reports & insights',
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _btnFree,
                foregroundColor: Color(0xFF1E293B),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Continue Free',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proCard() {
    final sub = ref.watch(subscriptionProvider);
    final isPerCrop = _cycle == _BillingCycle.perCrop;

    final title = isPerCrop ? 'PRO' : 'BUSINESS';
    final priceMain = isPerCrop ? '₹999' : '₹2999';
    final priceStrike = isPerCrop ? '₹2000' : '₹5999';
    final priceUnit = isPerCrop ? '/ crop' : '/ year';
    final tagText = isPerCrop
        ? 'Launch Price • Increasing soon'
        : 'Best for multi-farm users';

    final features = isPerCrop
        ? const [
            'Smart feed engine (tray + growth + FCR)',
            'Feed savings & ₹ impact tracking',
            'FCR monitoring & improvement',
            'Growth intelligence (ideal vs actual)',
            'Disease & risk alerts',
            'Multi-pond comparison',
            'Full crop report (PDF)',
          ]
        : const [
            'Everything in PRO',
            'Unlimited crops',
            'Multiple farms',
            'Worker / supervisor access',
            'Advanced analytics',
            'Priority support',
          ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.scale(
          scale: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceMain,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        priceStrike,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _strike,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: _strike,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        priceUnit,
                        style: const TextStyle(fontSize: 14, color: _muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tagText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _includedList(features),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: sub.isLoading
                        ? null
                        : () => ref
                            .read(subscriptionProvider.notifier)
                            .upgradeToPro(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: sub.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            isPerCrop ? 'Unlock PRO' : 'Unlock BUSINESS',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -10,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'MOST POPULAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _includedList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_rounded, size: 16, color: _accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                          fontSize: 13.5, color: _listInk, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _lockedList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.lock_rounded, size: 15, color: _lockRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                          fontSize: 13.5, color: _lockRed, height: 1.4),
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
