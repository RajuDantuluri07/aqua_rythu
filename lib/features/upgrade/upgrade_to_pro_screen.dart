import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_provider.dart';
import 'upgrade_insight_provider.dart';

// ── Design tokens (file-scoped) ──────────────────────────────────────────────
const _bg = Color(0xFFF5F7FA);
const _ink = Color(0xFF0E1A1F);
const _ink2 = Color(0xFF4A5560);
const _ink3 = Color(0xFF8A949C);
const _line = Color(0xFFECECE6);
const _line2 = Color(0xFFE2E2DB);
const _teal = Color(0xFF0B4A5C);
const _tealSoft = Color(0xFFE4EEF1);
const _greenHi = Color(0xFF2BA864);
const _greenDeep = Color(0xFF14613B);
const _greenDef = Color(0xFFDEF5E5);
const _amberSoft = Color(0xFFFFF4E0);
const _amber = Color(0xFFE8A33D);
const _roseSoft = Color(0xFFFBECEA);
const _roseInk = Color(0xFF9B3A2F);

enum _Check { teal, soft, none }

class UpgradeToProScreen extends ConsumerStatefulWidget {
  const UpgradeToProScreen({super.key});

  @override
  ConsumerState<UpgradeToProScreen> createState() => _State();
}

class _State extends ConsumerState<UpgradeToProScreen> {
  final _scroll = ScrollController();
  final _openFaq = <int>{0};

  @override
  void initState() {
    super.initState();
    UpgradeMetrics.track('paywall_view', {'screen': 'upgrade_to_pro'});
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(child: _appBar()),
              SliverToBoxAdapter(child: _hero()),
              SliverToBoxAdapter(child: _comparisonTable()),
              SliverToBoxAdapter(child: _planSectionHead()),
              SliverToBoxAdapter(child: _planCards()),
              SliverToBoxAdapter(child: _microProof()),
              SliverToBoxAdapter(child: _trustCard()),
              SliverToBoxAdapter(child: _faqSectionHead()),
              SliverToBoxAdapter(child: _faqList()),
              SliverToBoxAdapter(child: _legalFooter()),
              const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _stickyCta()),
        ],
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────
  Widget _appBar() {
    return Container(
      height: 84,
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 0),
      child: Row(
        children: [
          _circleBtn(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close_rounded, size: 16, color: _ink),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upgrade to ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink, letterSpacing: -0.1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_teal, Color(0xFF14778C)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4),
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'RESTORE',
              style: TextStyle(fontSize: 10, color: _ink3, letterSpacing: 0.6, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────
  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _ink, height: 1.1, letterSpacing: -0.5),
              children: [
                TextSpan(text: 'What you get\nwith '),
                TextSpan(text: 'PRO', style: TextStyle(color: _greenHi)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Everything you need to run a profitable crop — from stocking day to harvest.',
            style: TextStyle(fontSize: 14, color: _ink2, height: 1.45),
          ),
        ],
      ),
    );
  }

  // ── Comparison table ─────────────────────────────────────────────────────
  Widget _comparisonTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            _cmpHead(),
            _cmpSection('Smart Feeding'),
            _cmpRow('Feed schedule (DOC 1–60)', 'Standard chart for first 30 days', free: _Check.soft, pro: _Check.teal),
            _cmpRow('Smart feeding alerts', 'Daily, based on weather', free: _Check.none, pro: _Check.teal),
            _cmpRow('Defects & water-flow alerts', 'Early-warning anomaly detection', free: _Check.none, pro: _Check.teal),
            _cmpRow('Track crop growth vs ideal', 'Daily weight & size benchmark', free: _Check.none, pro: _Check.teal),
            _cmpSection('Insights & Reports'),
            _cmpRow('Disease early-warning', 'WSSV, EHP, white-gut signals', free: _Check.none, pro: _Check.teal),
            _cmpRow('Visual feed report', 'Weekly PDF you can share', free: _Check.soft, pro: _Check.teal),
            _cmpRow('Multi-pond compare', 'Side-by-side performance', free: _Check.none, pro: _Check.teal),
            _cmpRow('Crop report (PDF)', 'End-of-cycle summary', free: _Check.none, pro: _Check.teal),
            _cmpSection('Support'),
            _cmpRow('WhatsApp expert support', 'Telugu / Hindi / English', free: _Check.none, pro: _Check.teal),
            _cmpRow('Hatchery recommendations', 'Verified seed quality', free: _Check.none, pro: _Check.teal),
          ],
        ),
      ),
    );
  }

  Widget _cmpHead() {
    return Container(
      color: const Color(0xFFF6F6F1),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 0, 12),
              child: Text('FEATURE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink3, letterSpacing: 0.8)),
            ),
          ),
          const SizedBox(
            width: 56,
            child: Center(child: Text('FREE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink3, letterSpacing: 0.8))),
          ),
          Container(
            width: 56,
            color: _teal,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: const Text('PRO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _cmpSection(String title) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF0F4F2),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF062F3B), letterSpacing: 0.6),
      ),
    );
  }

  Widget _cmpRow(String label, String sub, {required _Check free, required _Check pro}) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: _ink, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 11.5, color: _ink3, height: 1.3)),
                ],
              ),
            ),
          ),
          SizedBox(width: 56, child: Center(child: _checkIcon(free))),
          SizedBox(width: 56, child: Center(child: _checkIcon(pro))),
        ],
      ),
    );
  }

  Widget _checkIcon(_Check type) {
    switch (type) {
      case _Check.teal:
        return Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
        );
      case _Check.soft:
        return Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(color: _greenHi, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
        );
      case _Check.none:
        return Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(color: Color(0xFFF0F0EA), shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, size: 11, color: Color(0xFFB8B8B0)),
        );
    }
  }

  // ── Plan section header ───────────────────────────────────────────────────
  Widget _planSectionHead() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 32, 22, 12),
      child: Column(
        children: [
          Text('— Pick your plan', style: TextStyle(fontSize: 11, color: _greenHi, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          SizedBox(height: 6),
          Text('Choose Your Plan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.4, height: 1.15)),
          SizedBox(height: 4),
          Text('7-day free trial · cancel anytime', style: TextStyle(fontSize: 13, color: _ink3)),
        ],
      ),
    );
  }

  // ── Plan cards ───────────────────────────────────────────────────────────
  Widget _planCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _featuredCard(),
          const SizedBox(height: 14),
          _saverCard(),
        ],
      ),
    );
  }

  Widget _featuredCard() {
    final sub = ref.watch(subscriptionProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _greenHi, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4FBF6), Colors.white],
              stops: [0.0, 0.6],
            ),
            boxShadow: [BoxShadow(color: _greenHi.withOpacity(0.14), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Smart Crop Plan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.1)),
                            SizedBox(width: 6),
                            Icon(Icons.star_rounded, size: 14, color: _amber),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('₹499', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.6, height: 1)),
                            SizedBox(width: 6),
                            Text('/ crop', style: TextStyle(fontSize: 13, color: _ink3)),
                            SizedBox(width: 4),
                            Text('₹999', style: TextStyle(fontSize: 14, color: _ink3, decoration: TextDecoration.lineThrough)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _planTag('1 POND'),
                ],
              ),
              const SizedBox(height: 10),
              _savingsPill(
                color: _greenDef,
                textColor: _greenDeep,
                text: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _greenDeep),
                    children: [
                      TextSpan(text: 'Save up to '),
                      TextSpan(text: '₹13,000', style: TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: ' per crop on losses'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _featureList(['All Smart Feeding features', 'Disease early-warning + alerts', 'End-of-crop PDF report']),
              const SizedBox(height: 14),
              _primaryBtn(
                label: 'Start free trial',
                loading: sub.isLoading,
                onTap: () => ref.read(subscriptionProvider.notifier).upgradeToPro(),
              ),
            ],
          ),
        ),
        Positioned(
          top: -10,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _greenHi, borderRadius: BorderRadius.circular(4)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 9, color: Colors.white),
                SizedBox(width: 5),
                Text('MOST POPULAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.8)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _saverCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line, width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Multi Crop Saver Plan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.1)),
                    SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('₹999', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.6, height: 1)),
                        SizedBox(width: 6),
                        Text('/ year (3 crops)', style: TextStyle(fontSize: 13, color: _ink3)),
                      ],
                    ),
                  ],
                ),
              ),
              _planTag('∞ PONDS'),
            ],
          ),
          const SizedBox(height: 10),
          _savingsPill(
            color: _amberSoft,
            textColor: const Color(0xFF6B4A0A),
            text: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B4A0A)),
                children: [
                  TextSpan(text: 'Best value: '),
                  TextSpan(text: '₹333', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: ' / crop · save 33%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _featureList(['Everything in Smart Crop Plan', 'Unlimited ponds & multi-pond compare', 'Priority WhatsApp expert support']),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: _line2, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Choose Saver', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Micro proof ───────────────────────────────────────────────────────────
  Widget _microProof() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(child: _mpItem(Icons.star_border_rounded, '4.8', ' rating · 4,200+ farmers')),
          const SizedBox(width: 8),
          Expanded(child: _mpItem(Icons.arrow_forward_rounded, '14-day', ' money back')),
        ],
      ),
    );
  }

  Widget _mpItem(IconData icon, String bold, String rest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _teal),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11.5, color: _ink2, height: 1.3),
                children: [
                  TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                  TextSpan(text: rest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Trust card ────────────────────────────────────────────────────────────
  Widget _trustCard() {
    const items = [
      (Icons.check_circle_outline_rounded, 'Built for Indian shrimp farmers — Vannamei + Black Tiger'),
      (Icons.cloud_off_rounded, 'Works offline — syncs when you\'re back online'),
      (Icons.lock_outline_rounded, 'No commission, no kickbacks — your data stays yours'),
      (Icons.trending_up_rounded, 'Pay once per crop — no hidden auto-renewal traps'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: _roseSoft, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.favorite_rounded, size: 12, color: _roseInk),
                ),
                const SizedBox(width: 8),
                const Text('Why farmers trust AquaPro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.1)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: _tealSoft, borderRadius: BorderRadius.circular(7)),
                    child: Icon(t.$1, size: 13, color: _teal),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.$2, style: const TextStyle(fontSize: 12.5, color: _ink2, height: 1.35))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ── FAQ ───────────────────────────────────────────────────────────────────
  Widget _faqSectionHead() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 32, 22, 12),
      child: Column(
        children: [
          Text('— Need help?', style: TextStyle(fontSize: 11, color: _greenHi, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          SizedBox(height: 6),
          Text('Common Questions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.4, height: 1.15)),
        ],
      ),
    );
  }

  Widget _faqList() {
    const faqs = [
      ('Will PRO really pay back?', 'Average AquaPro farmer saves ₹8,400 per crop through better feeding and earlier disease detection. Most users break even in under 18 days.'),
      ('Does this work without sensors?', 'Yes. Log readings manually in the app — AquaPro learns your pond and gives the same recommendations. IoT sensors auto-sync if you have them.'),
      ('What if my crop fails?', 'If you cancel mid-crop we refund the unused portion. WhatsApp support stays with you until the end of the cycle.'),
      ('Can I use it for multiple ponds?', 'Smart Crop Plan covers 1 pond. Multi Crop Saver covers unlimited ponds with side-by-side comparison.'),
      ('Is payment one-time?', 'Smart Crop Plan is one-time per crop. Multi Crop Saver is annual. Both can be cancelled anytime, no auto-traps.'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: faqs.indexed.map((entry) {
            final (i, faq) = entry;
            final open = _openFaq.contains(i);
            return _FaqRow(
              question: faq.$1,
              answer: faq.$2,
              isOpen: open,
              showTopBorder: i > 0,
              onToggle: () => setState(() => open ? _openFaq.remove(i) : _openFaq.add(i)),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Legal footer ──────────────────────────────────────────────────────────
  Widget _legalFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Column(
        children: [
          const Text(
            'By subscribing you agree to our Terms.\nManage in Settings · Cancel anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _ink3, height: 1.6),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(onTap: () {}, child: const Text('Terms', style: TextStyle(fontSize: 11, color: _ink2))),
              const SizedBox(width: 12),
              GestureDetector(onTap: () {}, child: const Text('Privacy', style: TextStyle(fontSize: 11, color: _ink2))),
              const SizedBox(width: 12),
              GestureDetector(onTap: () {}, child: const Text('Restore', style: TextStyle(fontSize: 11, color: _ink2))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sticky CTA ────────────────────────────────────────────────────────────
  Widget _stickyCta() {
    final sub = ref.watch(subscriptionProvider);
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.93),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('SMART CROP PLAN', style: TextStyle(fontSize: 10, color: _ink3, letterSpacing: 0.6)),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.3),
                  children: [
                    TextSpan(text: '₹999  ', style: TextStyle(color: _ink3, fontWeight: FontWeight.w400, fontSize: 13, decoration: TextDecoration.lineThrough)),
                    TextSpan(text: '₹499'),
                    TextSpan(text: '/crop', style: TextStyle(fontSize: 11, color: _ink3, fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: sub.isLoading ? null : () => ref.read(subscriptionProvider.notifier).upgradeToPro(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _greenHi,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 42),
              shape: const StadiumBorder(),
            ),
            child: sub.isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Start free trial', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.1)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _planTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFF0F0EA), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _ink2, letterSpacing: 0.4)),
    );
  }

  Widget _savingsPill({required Color color, required Color textColor, required Widget text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: textColor),
          const SizedBox(width: 6),
          text,
        ],
      ),
    );
  }

  Widget _featureList(List<String> items) {
    return Column(
      children: items.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_rounded, size: 14, color: _greenHi),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(f, style: const TextStyle(fontSize: 13, color: _ink, height: 1.35))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _primaryBtn({required String label, required bool loading, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _greenHi,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
      ),
    );
  }

  Widget _circleBtn({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), shape: BoxShape.circle),
        child: Center(child: child),
      ),
    );
  }
}

// ── FAQ row ──────────────────────────────────────────────────────────────────
class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.question,
    required this.answer,
    required this.isOpen,
    required this.showTopBorder,
    required this.onToggle,
  });

  final String question;
  final String answer;
  final bool isOpen;
  final bool showTopBorder;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: showTopBorder ? const Border(top: BorderSide(color: _line)) : null,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isOpen ? FontWeight.w600 : FontWeight.w500,
                      color: _ink,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _ink3),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(answer, style: const TextStyle(fontSize: 12.5, color: _ink2, height: 1.5)),
              ),
              crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}
