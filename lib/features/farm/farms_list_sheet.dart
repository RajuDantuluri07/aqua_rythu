import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/core/services/farm/farm_member_service.dart';
import 'package:aqua_rythu/core/services/limit_trigger_service.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'farm_provider.dart';
import 'farm_detail_sheet.dart';
import '../profile/farm_settings_screen.dart';
import 'package:aqua_rythu/features/upgrade/widgets/farm_limit_bottom_sheet.dart';

class FarmsListSheet extends ConsumerWidget {
  const FarmsListSheet({super.key});

  static const _primaryGreen = Color(0xFF1B8A4C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);
    final farms = farmState.farms;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2F4F6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  const Text(
                    'My Farms',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${farms.length} farm${farms.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: _primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: farms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.agriculture_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          const Text('No farms added yet',
                              style: TextStyle(color: Color(0xFF888888))),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Check farm limit before opening form
                              if (LimitTriggerService.hasHitFarmLimit(
                                  farms.length)) {
                                await FarmLimitBottomSheet.show(context);
                                return;
                              }
                              Navigator.of(context).pop();
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.addFarm);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add New Farm'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: farms.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i < farms.length) return _FarmCard(farm: farms[i]);
                        // Add New Farm button at bottom of list
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                // Check farm limit before opening form
                                if (LimitTriggerService.hasHitFarmLimit(
                                    farms.length)) {
                                  await FarmLimitBottomSheet.show(context);
                                  return;
                                }
                                Navigator.of(context).pop();
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.addFarm);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primaryGreen,
                                side: const BorderSide(
                                    color: _primaryGreen, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(
                                'Add New Farm',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmCard extends StatefulWidget {
  final Farm farm;
  const _FarmCard({required this.farm});

  @override
  State<_FarmCard> createState() => _FarmCardState();
}

class _FarmCardState extends State<_FarmCard> {
  static const _primaryGreen = Color(0xFF1B8A4C);
  int _memberCount = 0;
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _fetchMemberCount();
  }

  Future<void> _fetchMemberCount() async {
    try {
      final members =
          await FarmMemberService().getMembersForFarm(widget.farm.id);
      if (mounted) setState(() => _memberCount = members.length);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FarmDetailSheet(farm: widget.farm),
    );
  }

  void _openFarmSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FarmSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalArea = widget.farm.ponds.fold(0.0, (sum, p) => sum + p.area);

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.water_drop,
                      color: _primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.farm.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: Color(0xFF888888)),
                          const SizedBox(width: 2),
                          Text(
                            widget.farm.location,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF888888)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _openFarmSettings(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: Colors.grey.shade600,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFBBBBBB), size: 20),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _chip(Icons.shield_outlined, 'Farmer', _primaryGreen),
                const SizedBox(width: 8),
                _chip(
                  Icons.water_outlined,
                  '${widget.farm.ponds.length} Pond${widget.farm.ponds.length == 1 ? '' : 's'}',
                  const Color(0xFF1565C0),
                ),
                const SizedBox(width: 8),
                _chip(
                  Icons.group_outlined,
                  _loadingMembers
                      ? '...'
                      : '$_memberCount Member${_memberCount == 1 ? '' : 's'}',
                  const Color(0xFF6A1B9A),
                ),
              ],
            ),

            if (totalArea > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip(
                    Icons.straighten_outlined,
                    '${totalArea.toStringAsFixed(1)} acres',
                    const Color(0xFFE65100),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
