import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'upgrade_insight_provider.dart';
import 'widgets/dynamic_savings_hero.dart';
import 'widgets/value_proof_section.dart';
import 'widgets/how_it_works_section.dart';
import 'widgets/feature_comparison_table.dart';
import 'widgets/pricing_cards_section.dart';
import 'widgets/trust_reinforcement_widget.dart';
import 'widgets/objection_handling_section.dart';
import 'widgets/sticky_cta_bar.dart';

class UpgradeToProScreen extends ConsumerStatefulWidget {
  const UpgradeToProScreen({super.key});

  @override
  ConsumerState<UpgradeToProScreen> createState() => _UpgradeToProScreenState();
}

class _UpgradeToProScreenState extends ConsumerState<UpgradeToProScreen> {
  final _scrollController = ScrollController();
  final _pricingKey = GlobalKey();
  late final DateTime _openedAt;
  double _maxScrollDepth = 0;
  bool _pricingFocused = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    UpgradeMetrics.track('paywall_view', {'screen': 'upgrade_to_pro'});
    _scrollController.addListener(_trackScrollDepth);

    if (upgradeExperimentFlags.autoScrollToPricing) {
      Future.delayed(const Duration(seconds: 4), _focusPricing);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_trackScrollDepth);
    _scrollController.dispose();
    UpgradeMetrics.track('paywall_time_on_page', {
      'seconds': DateTime.now().difference(_openedAt).inSeconds,
      'max_scroll_depth': _maxScrollDepth.round(),
    });
    super.dispose();
  }

  void _trackScrollDepth() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    final depth = (position.pixels / position.maxScrollExtent) * 100;
    if (depth > _maxScrollDepth) {
      _maxScrollDepth = depth.clamp(0, 100).toDouble();
    }
  }

  void _focusPricing() {
    if (!mounted || _pricingFocused) return;
    final context = _pricingKey.currentContext;
    if (context == null) return;
    _pricingFocused = true;
    UpgradeMetrics.track('pricing_auto_focus', {'delay_seconds': 4});
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Upgrade to PRO',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              children: [
                DynamicSavingsHero(onPrimaryCta: _focusPricing),
                const HowItWorksSection(),
                const ValueProofSection(),
                const FeatureComparisonTable(),
                PricingCardsSection(key: _pricingKey),
                const TrustReinforcementWidget(),
                const ObjectionHandlingSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (upgradeExperimentFlags.stickyCtaEnabled)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: StickyCTABar(),
            ),
        ],
      ),
    );
  }
}
