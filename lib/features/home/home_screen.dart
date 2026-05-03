import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../farm/farm_provider.dart';
import '../farm/farm_switcher_sheet.dart';
import '../feed/feed_history_provider.dart';
import '../growth/growth_provider.dart';
import '../upgrade/upgrade_to_pro_screen.dart';
import '../upgrade/feature_gate.dart';
import '../upgrade/access_control_hooks.dart';
import '../../widgets/app_bottom_bar.dart';
import '../../core/language/app_localizations.dart';
import '../../core/services/admin_security_service.dart';
import '../../core/services/farm_price_settings_service.dart';
import '../../core/services/inventory_service.dart';
import '../../core/models/inventory_item.dart';
import '../../routes/app_routes.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _bg = Color(0xFFF5F7FA);
const _card = Colors.white;
const _ink = Color(0xFF0E1A1F);
const _ink2 = Color(0xFF4A5560);
const _ink3 = Color(0xFF8A949C);
const _line = Color(0xFFECECE6);
const _teal = Color(0xFF0B4A5C);
const _tealDeep = Color(0xFF062F3B);
const _greenSoft = Color(0xFFE5F2EA);
const _greenDeep = Color(0xFF14613B);
const _greenHi = Color(0xFF2BA864);
const _amber = Color(0xFFE8A33D);
const _amberSoft = Color(0xFFFFF4E0);
const _amberDeep = Color(0xFF6B4A0A);
const _orangeSoft = Color(0xFFFCEAD9);
const _orange = Color(0xFFC75B1E);
const _blueSoft = Color(0xFFE3EEFB);
const _blue = Color(0xFF2A6BD1);
const _roseInk = Color(0xFF9B3A2F);

const _mono = TextStyle(fontFamily: 'monospace');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// Feed savings: baseline FCR for "expected feed" benchmark.

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tapCount = 0;
  DateTime? _lastTapTime;
  static const Duration _tapResetTime = Duration(seconds: 3);
  static const int _requiredTaps = 5;

  void _handleFarmNameTap() {
    final adminService = AdminSecurityService();
    final user = Supabase.instance.client.auth.currentUser;
    if (!adminService.isAdmin(user)) return;

    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) > _tapResetTime) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTapTime = now;

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      _showAdminPasscodeDialog();
    }
  }

  void _showAdminPasscodeDialog() {
    final passcodeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Admin Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter admin passcode:'),
            const SizedBox(height: 16),
            TextField(
              controller: passcodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: '4-digit passcode',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final passcode = passcodeController.text.trim();
              Navigator.of(dialogContext).pop();
              if (passcode.isEmpty) return;
              try {
                final isValid =
                    await AdminSecurityService().validateAdminAccess(passcode);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isValid
                        ? 'Admin access granted! Session active for 15 minutes.'
                        : 'Invalid passcode'),
                    backgroundColor: isValid ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 3),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // ─── Data helpers ──────────────────────────────────────────────────────────

  double _totalFeed(List<Pond> ponds) {
    double total = 0;
    for (final p in ponds) {
      final history = ref.watch(feedHistoryProvider)[p.id] ?? [];
      for (final e in history) {
        total += (e.total as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  double _todayFeed(List<Pond> ponds) {
    final today = DateTime.now();
    double total = 0;
    for (final p in ponds) {
      final history = ref.watch(feedHistoryProvider)[p.id] ?? [];
      for (final e in history) {
        if (e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day) {
          total += (e.total as num?)?.toDouble() ?? 0;
        }
      }
    }
    return total;
  }

  double _pondFeedToday(Pond p) {
    final today = DateTime.now();
    double total = 0;
    final history = ref.read(feedHistoryProvider)[p.id] ?? [];
    for (final e in history) {
      if (e.date.year == today.year &&
          e.date.month == today.month &&
          e.date.day == today.day) {
        total += (e.total as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  double _pondFcr(Pond p) {
    try {
      final history = ref.read(feedHistoryProvider)[p.id] ?? [];
      if (history.isEmpty) return 0;
      double feed = 0;
      for (final e in history) {
        feed += (e.total as num?)?.toDouble() ?? 0;
      }
      final logs = ref.read(growthProvider(p.id));
      if (logs.isEmpty) return 0;
      final survival = _survivalRate(p.doc);
      final biomass = (p.seedCount * survival * logs.first.abw) / 1000;
      return biomass > 0 ? feed / biomass : 0;
    } catch (_) {
      return 0;
    }
  }

  ({double biomass, double? profit}) _farmBiomassProfit(
      List<Pond> ponds, {double? feedPrice, double? sellPrice}) {
    double biomass = 0, feed = 0;
    for (final p in ponds) {
      final logs = ref.watch(growthProvider(p.id));
      if (logs.isEmpty) continue;
      final survival = _survivalRate(p.doc);
      final b = (p.seedCount * survival * logs.first.abw) / 1000;
      biomass += b;
      final h = ref.watch(feedHistoryProvider)[p.id] ?? [];
      for (final e in h) {
        feed += (e.total as num?)?.toDouble() ?? 0;
      }
    }
    if (feedPrice == null || sellPrice == null) {
      return (biomass: biomass, profit: null);
    }
    final profit = biomass * sellPrice - feed * feedPrice;
    return (biomass: biomass, profit: profit);
  }

  double _survivalRate(int doc) {
    if (doc <= 0) return 0.85;
    if (doc <= 30) return 0.90;
    if (doc <= 60) return 0.85;
    if (doc <= 90) return 0.80;
    return 0.75;
  }


  ({int score, String label}) _healthScore(List<Pond> ponds) {
    if (ponds.isEmpty) return (score: 100, label: 'Excellent');
    double total = 0;
    int count = 0;
    for (final p in ponds) {
      final fcr = _pondFcr(p);
      if (fcr <= 0) continue;
      double s = 100;
      if (fcr > 2.0) {
        s = 60;
      } else if (fcr > 1.8) {
        s = 70;
      } else if (fcr > 1.5) {
        s = 80;
      } else if (fcr > 1.3) {
        s = 90;
      }
      total += s;
      count++;
    }
    final score = count > 0 ? (total / count).round() : 100;
    final label = score >= 90 ? 'Excellent' : score >= 70 ? 'Good' : 'Needs Attention';
    return (score: score, label: label);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final farm = farmState.currentFarm;
    final ponds = (farm?.ponds ?? []).cast<Pond>()
        .where((p) => p.status == PondStatus.active)
        .toList();

    if (farm == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).t('home')),
          backgroundColor: _bg,
          elevation: 0,
        ),
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.landscape_outlined, size: 64, color: _ink3),
              SizedBox(height: 16),
              Text('No farm found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final priceSettings = ref
        .watch(farmPriceSettingsProvider(farm.id))
        .valueOrNull;
    final feedPrice = priceSettings?.feedPricePerKg;
    final sellPrice = priceSettings?.sellPricePerKg;

    final totalFeed = _totalFeed(ponds);
    final todayFeed = _todayFeed(ponds);
    final cost = feedPrice != null ? totalFeed * feedPrice : null;
    final bp = _farmBiomassProfit(ponds, feedPrice: feedPrice, sellPrice: sellPrice);
    final health = _healthScore(ponds);
    final gate = ref.watch(featureGateProvider);
    final minDoc = ponds.isNotEmpty
        ? ponds.map((p) => p.doc).reduce(math.min)
        : 0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AppBar(
                    farmName: farm.name,
                    doc: minDoc,
                    pondCount: ponds.length,
                    onIconSecretTap: _handleFarmNameTap,
                    onNameTap: () => FarmSwitcherSheet.show(context),
                    onUpgradeTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UpgradeToProScreen()),
                    ),
                  ),
                  _HeroStrip(
                    totalFeed: totalFeed,
                    todayFeed: todayFeed,
                    cost: cost,
                  ),
                  _StatsGrid(
                    biomass: bp.biomass,
                    profit: bp.profit,
                    healthScore: health.score,
                    healthLabel: health.label,
                    isPro: gate.canViewProfit,
                  ),
                  _SectionHeader(
                    title: 'Inventory & Expense',
                    right: 'MANAGE',
                    onRight: () => Navigator.pushNamed(
                        context, AppRoutes.inventoryDashboard),
                  ),
                  _QuickRow(
                    farmId: farm.id,
                    onInventory: () => Navigator.pushNamed(
                        context, AppRoutes.inventoryDashboard),
                    onExpense: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.addExpense,
                        arguments: {
                          'cropId': farm.id,
                          'farmId': farm.id,
                        },
                      );
                    },
                  ),
                  _TodaysActions(ponds: ponds, ref: ref),
                  _PondsSection(
                    ponds: ponds,
                    pondFeedToday: _pondFeedToday,
                    pondFcr: _pondFcr,
                    canViewFcr: gate.canViewFcr,
                    onViewAll: () =>
                        Navigator.pushNamed(context, AppRoutes.pondDashboard),
                    onPondTap: (p) => Navigator.pushNamed(
                        context, AppRoutes.feedSchedule,
                        arguments: p.id),
                  ),
                  _UpgradeNudge(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UpgradeToProScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final String farmName;
  final int doc;
  final int pondCount;
  final VoidCallback onNameTap;
  final VoidCallback onIconSecretTap;
  final VoidCallback onUpgradeTap;

  const _AppBar({
    required this.farmName,
    required this.doc,
    required this.pondCount,
    required this.onNameTap,
    required this.onIconSecretTap,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    final shortName = farmName.length > 12 ? farmName.substring(0, 12) : farmName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onIconSecretTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _greenSoft,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _greenHi.withOpacity(0.2)),
              ),
              child: const Center(
                child: Icon(Icons.set_meal_rounded, color: _greenHi, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onNameTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Hi, $shortName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                            letterSpacing: -0.01 * 16,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: _ink2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'DOC ${doc.toString().padLeft(2, '0')} · $pondCount ACTIVE POND${pondCount != 1 ? 'S' : ''}',
                    style: _mono.copyWith(
                      fontSize: 11,
                      color: _ink3,
                      letterSpacing: 0.04 * 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onUpgradeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8A33D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 13, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _BellButton(),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _card,
        shape: BoxShape.circle,
        border: Border.all(color: _line),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.notifications_outlined, color: _ink2, size: 18),
          ),
          Positioned(
            top: 8,
            right: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _roseInk,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Strip ───────────────────────────────────────────────────────────────

class _HeroStrip extends StatelessWidget {
  final double totalFeed;
  final double todayFeed;
  final double? cost;

  const _HeroStrip({
    required this.totalFeed,
    required this.todayFeed,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    final costL = cost != null ? cost! / 100000 : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B4A5C), Color(0xFF0F6B7E)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _greenHi.withOpacity(0.45),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.65],
                  center: const Alignment(-0.4, -0.4),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _HeroStat(
                label: 'Total Feed',
                value: totalFeed.toStringAsFixed(0),
                unit: 'kg',
              ),
              _heroDivider(),
              _HeroStat(
                label: "Today's Feed",
                value: todayFeed.toStringAsFixed(0),
                unit: 'kg',
              ),
              _heroDivider(),
              _HeroStat(
                label: 'Cost',
                value: costL != null ? '₹${costL.toStringAsFixed(1)}' : '—',
                unit: costL != null ? 'L' : '',
                prefix: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(
        width: 1,
        height: 32,
        color: Colors.white.withOpacity(0.18),
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final bool prefix;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.unit,
    this.prefix = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: _mono.copyWith(
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 0.08 * 10,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.01 * 20,
                  height: 1,
                ),
              ),
              if (!prefix) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final double biomass;
  final double? profit;
  final int healthScore;
  final String healthLabel;
  final bool isPro;

  const _StatsGrid({
    required this.biomass,
    required this.profit,
    required this.healthScore,
    required this.healthLabel,
    required this.isPro,
  });

  @override
  Widget build(BuildContext context) {
    final profitL = profit != null ? profit! / 100000 : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Estimated Biomass',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            biomass.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                              letterSpacing: -0.02 * 22,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'kg',
                            style: TextStyle(fontSize: 13, color: _ink3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        biomass == 0
                            ? 'Updates after first sampling'
                            : 'From growth samples',
                        style: const TextStyle(fontSize: 11, color: _ink3),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Profit card — locked for FREE users; hidden until prices set
              Expanded(
                child: GestureDetector(
                  onTap: isPro
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const UpgradeToProScreen()),
                          ),
                  child: _StatCard(
                    label: 'Estimated Profit',
                    child: !isPro
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lock_outline_rounded,
                                      size: 15, color: _ink3),
                                  SizedBox(width: 5),
                                  Text(
                                    '₹—',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: _ink3,
                                      letterSpacing: -0.02 * 22,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Unlock profit insights',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : profitL == null
                            ? const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₹—',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: _ink3,
                                      letterSpacing: -0.02 * 22,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Set prices in Settings',
                                    style: TextStyle(
                                        fontSize: 11, color: _amber),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '₹${profitL.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: _ink,
                                          letterSpacing: -0.02 * 22,
                                          height: 1,
                                        ),
                                      ),
                                      const Text(
                                        'L',
                                        style: TextStyle(
                                            fontSize: 14, color: _ink3),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    profitL >= 0
                                        ? 'Based on your prices'
                                        : 'Loss — review costs',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: profitL >= 0
                                          ? _greenHi
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FarmHealthCard(score: healthScore, label: healthLabel, isPro: isPro),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _StatCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: _mono.copyWith(
              fontSize: 10,
              color: _ink3,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08 * 10,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FarmHealthCard extends StatelessWidget {
  final int score;
  final String label;
  final bool isPro;

  const _FarmHealthCard({required this.score, required this.label, required this.isPro});

  @override
  Widget build(BuildContext context) {
    if (!isPro) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UpgradeToProScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: _line),
                ),
                child: const Center(
                  child: Icon(Icons.lock_outline_rounded, size: 16, color: _ink3),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FARM HEALTH STATUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _ink3,
                        letterSpacing: 0.8,
                        fontFamily: 'monospace',
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'FCR-based score — PRO feature',
                      style: TextStyle(fontSize: 12, color: _ink3),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _amberSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'UNLOCK',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _amberDeep,
                    letterSpacing: 0.6,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pct = score / 100;
    const circumference = 2 * math.pi * 16;
    final offset = circumference * (1 - pct);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FARM HEALTH STATUS',
            style: _mono.copyWith(
              fontSize: 10,
              color: _ink3,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08 * 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(38, 38),
                      painter: _RingPainter(
                        progress: pct,
                        trackColor: _greenSoft,
                        fillColor: _greenHi,
                        strokeWidth: 4,
                        circumference: circumference,
                        dashOffset: offset,
                      ),
                    ),
                    Center(
                      child: Text(
                        '$score',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _greenDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _greenDeep,
                        letterSpacing: -0.02 * 22,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score >= 90
                          ? 'FCR is excellent across ponds'
                          : score >= 70
                              ? 'FCR is good, monitor feed closely'
                              : 'FCR needs attention — review feeding',
                      style: const TextStyle(fontSize: 11.5, color: _ink2),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: score >= 90
                      ? _greenSoft
                      : score >= 70
                          ? _amberSoft
                          : const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: _mono.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: score >= 90
                        ? _greenDeep
                        : score >= 70
                            ? _amberDeep
                            : const Color(0xFF8B1A1A),
                    letterSpacing: 0.06 * 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;
  final double circumference;
  final double dashOffset;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
    required this.circumference,
    required this.dashOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String right;
  final VoidCallback? onRight;

  const _SectionHeader({
    required this.title,
    required this.right,
    this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.08 * 12,
              color: _ink,
            ),
          ),
          GestureDetector(
            onTap: onRight,
            child: Text(
              right,
              style: _mono.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _greenHi,
                letterSpacing: 0.04 * 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick row: Inventory + Expense ──────────────────────────────────────────

final _inventorySummaryProvider =
    FutureProvider.family<({int total, int low}), String>((ref, farmId) async {
  final rows = await InventoryService().getInventoryStock(farmId);
  final items = rows.map(InventoryItem.fromView).toList();
  final low = items
      .where((i) =>
          i.status == PackStatus.low || i.status == PackStatus.critical)
      .length;
  return (total: items.length, low: low);
});

class _QuickRow extends ConsumerWidget {
  final VoidCallback onInventory;
  final VoidCallback onExpense;
  final String farmId;

  const _QuickRow({
    required this.onInventory,
    required this.onExpense,
    required this.farmId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(_inventorySummaryProvider(farmId));
    final invMeta = invAsync.when(
      data: (s) => s.total == 0
          ? 'No inventory data yet'
          : s.low > 0
              ? '${s.low} item${s.low > 1 ? 's' : ''} low · ${s.total} stocked'
              : '${s.total} items stocked',
      loading: () => 'Loading...',
      error: (_, __) => 'Tap to view',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickCard(
              label: 'Inventory',
              meta: invMeta,
              bg: _blueSoft,
              iconBg: _blue,
              textColor: const Color(0xFF1A4585),
              icon: Icons.inventory_2_rounded,
              onTap: onInventory,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickCard(
              label: 'Expense',
              meta: 'Tap to view expenses',
              bg: _orangeSoft,
              iconBg: _orange,
              textColor: const Color(0xFF6B2F0E),
              icon: Icons.receipt_long_rounded,
              onTap: onExpense,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String label;
  final String meta;
  final Color bg;
  final Color iconBg;
  final Color textColor;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({
    required this.label,
    required this.meta,
    required this.bg,
    required this.iconBg,
    required this.textColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.01 * 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              style: const TextStyle(
                fontSize: 11,
                color: _ink2,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Today's Actions ─────────────────────────────────────────────────────────

class _TodaysActions extends StatelessWidget {
  final List<Pond> ponds;
  final WidgetRef ref;

  const _TodaysActions({required this.ponds, required this.ref});

  @override
  Widget build(BuildContext context) {
    final actions = <_ActionData>[];

    for (final p in ponds) {
      final logs = ref.read(growthProvider(p.id));
      final needsSampling = logs.isEmpty ||
          DateTime.now().difference(logs.first.date).inDays > 14;

      if (needsSampling) {
        final isUrgent = actions.isEmpty; // first one is urgent
        actions.add(_ActionData(
          pond: p,
          urgent: isUrgent,
          title: 'Do sampling today',
          desc: 'Critical for biomass estimation. Skipping risks under/over-feeding for the next 7 days.',
          dueTime: isUrgent ? '6:00 PM' : '7:00 PM',
        ));
      }
    }

    final pendingCount = actions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: "Today's Actions",
          right: pendingCount > 0 ? '$pendingCount PENDING' : 'ALL DONE',
        ),
        if (actions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _greenHi, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'All caught up for today!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _greenDeep,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: actions
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AlertCard(
                          data: a,
                          onStart: () => Navigator.pushNamed(
                            context,
                            AppRoutes.feedSchedule,
                            arguments: a.pond.id,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _ActionData {
  final Pond pond;
  final bool urgent;
  final String title;
  final String desc;
  final String dueTime;

  const _ActionData({
    required this.pond,
    required this.urgent,
    required this.title,
    required this.desc,
    required this.dueTime,
  });
}

class _AlertCard extends StatelessWidget {
  final _ActionData data;
  final VoidCallback onStart;

  const _AlertCard({required this.data, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final isUrgent = data.urgent;
    final accentColor = isUrgent ? _amber : _orange;
    final bgGrad = isUrgent ? _amberSoft : _orangeSoft;
    final titleColor = isUrgent ? _amberDeep : _orange;
    final iconBg = isUrgent
        ? _amber.withOpacity(0.18)
        : _orange.withOpacity(0.16);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgGrad, Colors.white],
            stops: const [0, 0.6],
          ),
          border: Border.all(color: _line),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          color: titleColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            letterSpacing: -0.01 * 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data.pond.name,
                          style: _mono.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _ink2,
                            letterSpacing: 0.04 * 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.desc,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _ink2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SmallBtn(
                        label: 'Start sampling',
                        solid: true,
                        onTap: onStart,
                      ),
                      const SizedBox(width: 8),
                      _SmallBtn(label: 'Snooze', solid: false, onTap: () {}),
                      const Spacer(),
                      Text(
                        'due ${data.dueTime}',
                        style: _mono.copyWith(
                          fontSize: 11,
                          color: _ink3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final bool solid;
  final VoidCallback onTap;

  const _SmallBtn({
    required this.label,
    required this.solid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: solid ? _ink : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: solid ? Colors.white : _ink2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ponds section ────────────────────────────────────────────────────────────

class _PondsSection extends StatelessWidget {
  final List<Pond> ponds;
  final double Function(Pond) pondFeedToday;
  final double Function(Pond) pondFcr;
  final bool canViewFcr;
  final VoidCallback onViewAll;
  final void Function(Pond) onPondTap;

  const _PondsSection({
    required this.ponds,
    required this.pondFeedToday,
    required this.pondFcr,
    required this.canViewFcr,
    required this.onViewAll,
    required this.onPondTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: '${ponds.length} Active Pond${ponds.length != 1 ? 's' : ''}',
          right: 'VIEW ALL →',
          onRight: onViewAll,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: ponds
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PondCard(
                        pond: p,
                        feedToday: pondFeedToday(p),
                        fcr: pondFcr(p),
                        canViewFcr: canViewFcr,
                        onTap: () => onPondTap(p),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _PondCard extends StatelessWidget {
  final Pond pond;
  final double feedToday;
  final double fcr;
  final bool canViewFcr;
  final VoidCallback onTap;

  const _PondCard({
    required this.pond,
    required this.feedToday,
    required this.fcr,
    required this.canViewFcr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = fcr <= 1.4 || fcr == 0;
    final statusLabel = isGood ? 'GOOD' : 'WATCH';
    final statusColor = isGood ? _greenHi : _amber;
    final ledShadow = isGood
        ? _greenHi.withOpacity(0.18)
        : _amber.withOpacity(0.18);

    final doc = pond.doc;
    const cycleDays = 120;
    final progress = (doc / cycleDays).clamp(0.0, 1.0);
    final daysLeft = cycleDays - doc;

    final seedLac = (pond.seedCount / 100000).toStringAsFixed(1);
    final fcrText = fcr > 0 ? fcr.toStringAsFixed(1) : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: ledShadow,
                                  blurRadius: 0,
                                  spreadRadius: 3)
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 0.08 * 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          pond.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                            letterSpacing: -0.01 * 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${pond.area.toStringAsFixed(1)} AC · $seedLac LAC seed',
                          style: _mono.copyWith(
                            fontSize: 10,
                            color: _ink3,
                            letterSpacing: 0.04 * 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right_rounded, color: _ink3, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _line, style: BorderStyle.solid)),
              ),
              child: Row(
                children: [
                  _PondStat(label: 'DOC', value: doc.toString()),
                  _PondStat(
                      label: 'Feed (D)',
                      value: feedToday.toStringAsFixed(0),
                      unit: 'kg'),
                  if (canViewFcr)
                    _PondStat(
                        label: 'FCR',
                        value: fcrText,
                        dimmed: fcr == 0)
                  else
                    _LockedPondStat(
                      label: 'FCR',
                      onTap: () => AccessControlHooks.showUpgradeDialog(
                          context, FeatureIds.profitTracking),
                    ),
                  const _PondStat(label: 'DO', value: '—', dimmed: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: _greenSoft,
                valueColor: const AlwaysStoppedAnimation<Color>(_greenHi),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cycle progress',
                  style: _mono.copyWith(fontSize: 9.5, color: _ink3),
                ),
                Text(
                  '${(progress * 100).round()}% · ~$daysLeft days to harvest',
                  style: _mono.copyWith(
                    fontSize: 9.5,
                    color: _ink3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Shown in place of FCR for FREE users — lock icon, tap to upgrade.
class _LockedPondStat extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LockedPondStat({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: _mono.copyWith(
                fontSize: 9.5,
                color: _ink3,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06 * 9.5,
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.lock_outline_rounded, size: 13, color: _amber),
          ],
        ),
      ),
    );
  }
}

class _PondStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool dimmed;

  const _PondStat({
    required this.label,
    required this.value,
    this.unit,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: _mono.copyWith(
              fontSize: 9.5,
              color: _ink3,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.06 * 9.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: dimmed ? _ink3 : _ink,
                  letterSpacing: -0.01 * 14,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit!,
                  style: const TextStyle(fontSize: 10, color: _ink3),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Upgrade nudge ────────────────────────────────────────────────────────────

class _UpgradeNudge extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradeNudge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_teal, _tealDeep],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _greenHi.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _greenHi.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: _greenHi, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlock advanced farm insights',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.01 * 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Profit tracking, FCR analysis & smarter feed recommendations',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white70, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
