import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/constants/spacing.dart';
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
import '../../core/services/inventory_service.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/daily_action_engine.dart';
import '../../routes/app_routes.dart';
import '../expense/add_expense_screen.dart';
import '../dashboard/widgets/dashboard_metrics_grid.dart';

// ─── Design tokens (remaining custom colors not in design system) ───────────
const _teal = Color(0xFF0B4A5C);
const _tealDeep = Color(0xFF062F3B);
const _greenSoft = Color(0xFFE5F2EA);
const _greenHi = Color(0xFF2BA864);
const _amber = Color(0xFFE8A33D);
const _orangeSoft = Color(0xFFFCEAD9);
const _orange = Color(0xFFC75B1E);
const _blueSoft = Color(0xFFE3EEFB);
const _blue = Color(0xFF2A6BD1);
const _roseInk = Color(0xFF9B3A2F);

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
              final messenger = ScaffoldMessenger.of(context);
              try {
                final isValid =
                    await AdminSecurityService().validateAdminAccess(passcode);
                if (mounted) {
                  messenger.showSnackBar(SnackBar(
                    content: Text(isValid
                        ? 'Admin access granted! Session active for 15 minutes.'
                        : 'Invalid passcode'),
                    backgroundColor: isValid ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 3),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(SnackBar(
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

  void _showEditPondDialog(BuildContext context, Pond pond) {
    final nameController = TextEditingController(text: pond.name);
    final areaController = TextEditingController(text: pond.area.toString());
    final seedCountController = TextEditingController(text: pond.seedCount.toString());
    final plSizeController = TextEditingController(text: pond.plSize.toString());
    final traysController = TextEditingController(text: pond.numTrays.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Pond Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pond Name',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Pond 1',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              Text(
                'Area (Acres)',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: areaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'e.g., 2.5',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              Text(
                'Seed Count',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: seedCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g., 100000',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              Text(
                'PL Size (mm)',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: plSizeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g., 15',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              Text(
                'Number of Trays',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: traysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g., 3',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final area = double.tryParse(areaController.text);
              final seedCount = int.tryParse(seedCountController.text);
              final plSize = int.tryParse(plSizeController.text);
              final numTrays = int.tryParse(traysController.text);

              if (area == null || seedCount == null || plSize == null || numTrays == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid values for all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(dialogContext).pop();
              try {
                ref.read(farmProvider.notifier).updatePond(
                  pondId: pond.id,
                  name: nameController.text,
                  area: area,
                  seedCount: seedCount,
                  plSize: plSize,
                  stockingDate: pond.stockingDate,
                  numTrays: numTrays,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pond updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDeletePondDialog(BuildContext context, Pond pond) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Pond?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${pond.name}"?',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone. All data including feed logs, sampling records, and harvest history will be permanently deleted.',
              style: AppTextStyles.secondaryText.copyWith(
                color: AppColors.textSecondary,
              ),
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
              Navigator.of(dialogContext).pop();
              final messenger = ScaffoldMessenger.of(context);
              try {
                final farmState = ref.watch(farmProvider);
                final farmId = farmState.currentFarm?.id;

                if (farmId == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Error: Farm not found'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                await ref.read(farmProvider.notifier).deletePond(farmId, pond.id);

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${pond.name} deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Data helpers ──────────────────────────────────────────────────────────

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

  double _survivalRate(int doc) {
    if (doc <= 0) return 0.85;
    if (doc <= 30) return 0.90;
    if (doc <= 60) return 0.85;
    if (doc <= 90) return 0.80;
    return 0.75;
  }


  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final farm = farmState.currentFarm;
    final ponds = (farm?.ponds ?? []).cast<Pond>()
        .where((p) => p.status == PondStatus.active)
        .toList();

    if (farmState.accessDenied) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).t('home')),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
        body: AccessDeniedView(
          message: 'Unable to load your farm data. '
              'Please contact support if this persists.',
          onRetry: () =>
              ref.read(farmProvider.notifier).loadFarms(),
        ),
      );
    }

    if (farmState.loadError && farm == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).t('home')),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
        body: AccessDeniedView(
          message: 'Could not load farm data. '
              'Check your internet connection and tap Retry.',
          onRetry: () =>
              ref.read(farmProvider.notifier).loadFarms(),
        ),
      );
    }

    if (farm == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).t('home')),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.landscape_outlined, size: 64, color: AppColors.textSecondary),
              SizedBox(height: Spacing.lg),
              Text('No farm found',
                  style: AppTextStyles.heading),
            ],
          ),
        ),
      );
    }

    final gate = ref.watch(featureGateProvider);
    final minDoc = ponds.isNotEmpty
        ? ponds.map((p) => p.doc).reduce(math.min)
        : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: Spacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AppBar(
                    farmName: farm.name,
                    doc: minDoc,
                    pondCount: ponds.length,
                    isPro: gate.isPro,
                    onIconSecretTap: _handleFarmNameTap,
                    onNameTap: () => FarmSwitcherSheet.show(context),
                    onUpgradeTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UpgradeToProScreen()),
                    ),
                  ),
                  DashboardMetricsGrid(farmId: farm.id),
                  _TodaysActions(ponds: ponds, ref: ref),
                  _PondsSection(
                    ponds: ponds,
                    pondFeedToday: _pondFeedToday,
                    pondFcr: _pondFcr,
                    canViewFcr: gate.canViewFcr,
                    onViewAll: () =>
                        Navigator.pushNamed(context, AppRoutes.pondDashboard),
                    onPondTap: (p) => Navigator.pushNamed(
                        context, AppRoutes.pondDashboard,
                        arguments: p.id),
                    onPondEdit: _showEditPondDialog,
                    onPondDelete: _showDeletePondDialog,
                  ),
                  _UpgradeNudge(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UpgradeToProScreen()),
                    ),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(
                            cropId: farm.id,
                            farmId: farm.id,
                          ),
                        ),
                      );
                    },
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
  final bool isPro;
  final VoidCallback onNameTap;
  final VoidCallback onIconSecretTap;
  final VoidCallback onUpgradeTap;

  const _AppBar({
    required this.farmName,
    required this.doc,
    required this.pondCount,
    required this.isPro,
    required this.onNameTap,
    required this.onIconSecretTap,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    final shortName = farmName.length > 12 ? farmName.substring(0, 12) : farmName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
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
          const SizedBox(width: Spacing.sm),
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
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.textPrimary,
                            letterSpacing: -0.01 * 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.xs),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'DOC ${doc.toString().padLeft(2, '0')} · $pondCount ACTIVE POND${pondCount != 1 ? 'S' : ''}',
                    style: AppTextStyles.secondaryText.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
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
                color: isPro ? const Color(0xFF16A34A) : const Color(0xFFE8A33D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPro ? Icons.workspace_premium_rounded : Icons.workspace_premium_rounded,
                    size: 13,
                    color: isPro ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    isPro ? 'PRO ✓' : 'PRO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: isPro ? Colors.white : Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
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
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 18),
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
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          GestureDetector(
            onTap: onRight,
            child: Text(
              right,
              style: AppTextStyles.button.copyWith(
                color: AppColors.success,
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
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
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
          const SizedBox(width: Spacing.sm),
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
        padding: const EdgeInsets.all(Spacing.lg),
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
            const SizedBox(height: Spacing.sm),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.01 * 14,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              meta,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
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

class _TodaysActions extends StatefulWidget {
  final List<Pond> ponds;
  final WidgetRef ref;

  const _TodaysActions({required this.ponds, required this.ref});

  @override
  State<_TodaysActions> createState() => _TodaysActionsState();
}

class _TodaysActionsState extends State<_TodaysActions> {
  final Set<String> _snoozedPondIds = {};

  @override
  Widget build(BuildContext context) {
    // Collect actions from all ponds and find highest-priority type
    final actions = <DailyAction>[];
    for (final pond in widget.ponds) {
      if (!_snoozedPondIds.contains(pond.id)) {
        actions.add(DailyActionEngine.getTodaysAction(pond));
      }
    }

    // If no actions remain (all snoozed), hide section
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find highest-priority action type
    final topPriority = actions.map((a) => a.priority).reduce((a, b) => a < b ? a : b);
    final affectedPonds = actions.where((a) => a.priority == topPriority).toList();
    final topAction = affectedPonds.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: "Today's Actions",
          right: affectedPonds.length > 1
              ? '${affectedPonds.length} PONDS'
              : '1 ACTION',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: _ActionCard(
            action: topAction,
            affectedPondsCount: affectedPonds.length,
            onStart: () => Navigator.pushNamed(
              context,
              AppRoutes.feedSchedule,
              arguments: topAction.pond.id,
            ),
            onSnooze: () {
              setState(() {
                _snoozedPondIds.add(topAction.pond.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action snoozed for 1 hour')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final DailyAction action;
  final int affectedPondsCount;
  final VoidCallback onStart;
  final VoidCallback onSnooze;

  const _ActionCard({
    required this.action,
    required this.onStart,
    required this.onSnooze,
    this.affectedPondsCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = action.type.color;
    final bgGrad = accentColor.withOpacity(0.08);
    final titleColor = accentColor;
    final iconBg = accentColor.withOpacity(0.16);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgGrad, Colors.white],
            stops: const [0, 0.6],
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
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
                          action.type.icon,
                          color: titleColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    action.title,
                                    style: AppTextStyles.h2.copyWith(
                                      color: titleColor,
                                      letterSpacing: -0.01 * 16,
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
                                    affectedPondsCount > 1
                                        ? '$affectedPondsCount ponds'
                                        : action.pond.name,
                                    style: AppTextStyles.badge.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              action.message,
                              style: AppTextStyles.secondaryText.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: Spacing.sm),
                            Row(
                              children: [
                                _SmallBtn(
                                  label: 'View',
                                  solid: true,
                                  onTap: onStart,
                                ),
                                const SizedBox(width: Spacing.xs),
                                _SmallBtn(
                                  label: 'Snooze',
                                  solid: false,
                                  onTap: onSnooze,
                                ),
                                const Spacer(),
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
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: solid ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: solid
                ? AppTextStyles.button.copyWith(color: Colors.white)
                : AppTextStyles.secondaryText.copyWith(
                    color: AppColors.textSecondary,
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
  final Function(BuildContext, Pond)? onPondEdit;
  final Function(BuildContext, Pond)? onPondDelete;

  const _PondsSection({
    required this.ponds,
    required this.pondFeedToday,
    required this.pondFcr,
    required this.canViewFcr,
    required this.onViewAll,
    required this.onPondTap,
    this.onPondEdit,
    this.onPondDelete,
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
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Column(
            children: ponds
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: _PondCard(
                        pond: p,
                        feedToday: pondFeedToday(p),
                        fcr: pondFcr(p),
                        canViewFcr: canViewFcr,
                        onTap: () => onPondTap(p),
                        onEdit: onPondEdit != null ? (ctx) => onPondEdit!(ctx, p) : null,
                        onDelete: onPondDelete != null ? (ctx) => onPondDelete!(ctx, p) : null,
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
  final Function(BuildContext)? onEdit;
  final Function(BuildContext)? onDelete;

  const _PondCard({
    required this.pond,
    required this.feedToday,
    required this.fcr,
    required this.canViewFcr,
    required this.onTap,
    this.onEdit,
    this.onDelete,
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
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
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
                        const SizedBox(width: Spacing.xs),
                        Text(
                          statusLabel,
                          style: AppTextStyles.badge.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          pond.name,
                          style: AppTextStyles.h2.copyWith(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.01 * 16,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          '${pond.area.toStringAsFixed(1)} AC · $seedLac LAC seed',
                          style: AppTextStyles.meta.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit' && onEdit != null) {
                      onEdit!(context);
                    } else if (value == 'delete' && onDelete != null) {
                      onDelete!(context);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                          SizedBox(width: 12),
                          Text('Edit Pond'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Color(0xFFE53935)),
                          SizedBox(width: 12),
                          Text(
                            'Delete Pond',
                            style: TextStyle(color: Color(0xFFE53935)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.only(top: Spacing.sm),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border, style: BorderStyle.solid)),
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
                  _PondStat(
                    label: 'ABW',
                    value: pond.currentAbw != null ? pond.currentAbw!.toStringAsFixed(1) : '—',
                    unit: 'g',
                    dimmed: pond.currentAbw == null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: _greenSoft,
                valueColor: const AlwaysStoppedAnimation<Color>(_greenHi),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cycle progress',
                  style: AppTextStyles.smallLabel.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}% · ~$daysLeft days to harvest',
                  style: AppTextStyles.smallLabel.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
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
              style: AppTextStyles.smallLabel.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: Spacing.xs),
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
            style: AppTextStyles.smallLabel.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTextStyles.secondaryValue.copyWith(
                  fontSize: 14,
                  color: dimmed ? AppColors.textSecondary : AppColors.textPrimary,
                  letterSpacing: -0.01 * 14,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit!,
                  style: AppTextStyles.meta.copyWith(
                    color: AppColors.textSecondary,
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

// ─── Upgrade nudge ────────────────────────────────────────────────────────────

class _UpgradeNudge extends ConsumerWidget {
  final VoidCallback onTap;

  const _UpgradeNudge({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(featureGateProvider);
    if (gate.isPro) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, 0),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
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
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unlock advanced farm insights',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                          color: Colors.white,
                          letterSpacing: -0.01 * 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Profit tracking, FCR analysis & smarter feed recommendations',
                        style: AppTextStyles.caption.copyWith(
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
