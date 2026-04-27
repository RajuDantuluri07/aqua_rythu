import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/app_routes.dart';
import 'edit_farm_dialog.dart';
import 'farm_provider.dart';

class FarmSwitcherSheet extends ConsumerWidget {
  const FarmSwitcherSheet({super.key});

  static const _primaryGreen = Color(0xFF1B8A4C);
  static const _ink = Color(0xFF0E1A1F);
  static const _ink2 = Color(0xFF4A5560);
  static const _ink3 = Color(0xFF8A949C);
  static const _danger = Color(0xFFC23B2F);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FarmSwitcherSheet(),
    );
  }

  Future<void> _switchFarm(
    BuildContext context,
    WidgetRef ref,
    Farm farm,
  ) async {
    ref.read(farmProvider.notifier).selectFarm(farm.id);
    Navigator.of(context).pop();
  }

  Future<void> _editFarm(BuildContext context, Farm farm) async {
    Navigator.of(context).pop();
    await showDialog(
      context: context,
      builder: (_) => EditFarmDialog(
        farmId: farm.id,
        initialName: farm.name,
        initialLocation: farm.location,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Farm farm,
    int totalFarmCount,
  ) async {
    if (totalFarmCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Can't delete your only farm"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete farm?'),
        content: Text(
          'This will permanently delete "${farm.name}" and all its '
          '${farm.ponds.length} pond${farm.ponds.length == 1 ? '' : 's'} '
          'with their feed history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _danger),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(farmProvider.notifier).deleteFarm(farm.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${farm.name}" deleted'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: _danger,
          ),
        );
      }
    }
  }

  void _addFarm(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(AppRoutes.addFarm);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);
    final farms = farmState.farms;
    final selectedId = farmState.selectedId;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2F4F6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Switch farm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: _ink2,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: farms.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == farms.length) {
                    return _AddFarmButton(onTap: () => _addFarm(context));
                  }
                  final farm = farms[i];
                  final isCurrent = farm.id == selectedId;
                  return _FarmRow(
                    farm: farm,
                    isCurrent: isCurrent,
                    onSwitch: () => _switchFarm(context, ref, farm),
                    onEdit: () => _editFarm(context, farm),
                    onDelete: () => _confirmDelete(
                      context,
                      ref,
                      farm,
                      farms.length,
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

class _FarmRow extends StatelessWidget {
  final Farm farm;
  final bool isCurrent;
  final VoidCallback onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FarmRow({
    required this.farm,
    required this.isCurrent,
    required this.onSwitch,
    required this.onEdit,
    required this.onDelete,
  });

  static const _primaryGreen = FarmSwitcherSheet._primaryGreen;
  static const _ink = FarmSwitcherSheet._ink;
  static const _ink2 = FarmSwitcherSheet._ink2;
  static const _ink3 = FarmSwitcherSheet._ink3;
  static const _danger = FarmSwitcherSheet._danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isCurrent ? null : onSwitch,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? _primaryGreen : const Color(0xFFE8ECF0),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? _primaryGreen.withOpacity(0.12)
                      : const Color(0xFFF1F4F7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: isCurrent ? _primaryGreen : _ink2,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            farm.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _primaryGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'CURRENT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${farm.location.isNotEmpty ? farm.location : "No location"} · '
                      '${farm.ponds.length} pond${farm.ponds.length == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _ink3),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: _ink2),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: _danger),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFarmButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFarmButton({required this.onTap});

  static const _primaryGreen = FarmSwitcherSheet._primaryGreen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryGreen,
          side: const BorderSide(color: _primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'Add new farm',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
