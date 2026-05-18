import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crop_cycle.dart';
import '../utils/logger.dart';
import '../utils/uuid_generator.dart';

class CropCycleService {
  final _db = Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  // QUERIES
  // ─────────────────────────────────────────────────────────────────────────

  /// All operational (ACTIVE / PARTIAL_HARVEST) crop cycles for a farm.
  Future<List<CropCycle>> getActiveCycles(String farmId) async {
    final rows = await _db
        .from('crop_cycles')
        .select()
        .eq('farm_id', farmId)
        .inFilter('status', ['ACTIVE', 'PARTIAL_HARVEST'])
        .order('created_at', ascending: false);
    return rows.map((r) => CropCycle.fromMap(r)).toList();
  }

  /// Full history for a farm (all statuses).
  Future<List<CropCycle>> getCyclesForFarm(String farmId) async {
    final rows = await _db
        .from('crop_cycles')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false);
    return rows.map((r) => CropCycle.fromMap(r)).toList();
  }

  Future<CropCycle?> getCycleById(String cycleId) async {
    final row = await _db
        .from('crop_cycles')
        .select()
        .eq('id', cycleId)
        .maybeSingle();
    if (row == null) return null;
    return CropCycle.fromMap(row);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MUTATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Create a new farm-scoped crop cycle. Returns the created CropCycle.
  Future<CropCycle> createCycle({
    required String farmId,
    required String name,
    String? species,
    DateTime? stockingDate,
    DateTime? expectedHarvestDate,
    String? notes,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final data = {
      'id': generateUuidV4(),
      'farm_id': farmId,
      'name': name,
      if (species != null) 'species': species,
      if (stockingDate != null)
        'stocking_date': stockingDate.toIso8601String().split('T')[0],
      if (expectedHarvestDate != null)
        'expected_harvest_date':
            expectedHarvestDate.toIso8601String().split('T')[0],
      'status': 'ACTIVE',
      if (notes != null) 'notes': notes,
      'created_by': user.id,
    };

    final row =
        await _db.from('crop_cycles').insert(data).select().single();
    AppLogger.info('Created crop cycle: ${row['id']} — $name');
    return CropCycle.fromMap(row);
  }

  /// Assign a pond to a crop cycle (sets active_crop_id + pond_status).
  Future<void> assignPondToCycle({
    required String pondId,
    required String cycleId,
    required DateTime stockingDate,
  }) async {
    await _db.from('ponds').update({
      'active_crop_id': cycleId,
      'pond_status': PondLifecycleStatus.active.dbValue,
      'harvest_status': HarvestStatus.notStarted.dbValue,
      'stocked_at': stockingDate.toIso8601String(),
      'stocking_date': stockingDate.toIso8601String().split('T')[0],
      'status': 'active',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pondId);
    AppLogger.info('Pond $pondId assigned to cycle $cycleId');
  }

  /// Detach a pond from its crop cycle (harvest complete → pond back to PREP).
  Future<void> detachPondFromCycle(String pondId) async {
    await _db.from('ponds').update({
      'active_crop_id': null,
      'pond_status': PondLifecycleStatus.prep.dbValue,
      'harvest_status': HarvestStatus.notStarted.dbValue,
      'harvested_at': DateTime.now().toIso8601String(),
      'status': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pondId);
    AppLogger.info('Pond $pondId detached and set to PREP');
  }

  /// Mark a partial harvest on a pond.
  Future<void> markPondPartialHarvest(String pondId) async {
    await _db.from('ponds').update({
      'pond_status': PondLifecycleStatus.partialHarvest.dbValue,
      'harvest_status': HarvestStatus.partial.dbValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pondId);
  }

  /// Re-evaluate and update the crop cycle status based on its ponds.
  /// Call this after any pond harvest event.
  Future<void> syncCycleStatus(String cycleId) async {
    final ponds = await _db
        .from('ponds')
        .select('pond_status, harvest_status')
        .eq('active_crop_id', cycleId);

    if (ponds.isEmpty) {
      await _setCycleStatus(cycleId, CropStatus.completed);
      return;
    }

    final statuses =
        ponds.map((p) => p['pond_status'] as String? ?? 'ACTIVE').toList();
    final harvestStatuses =
        ponds.map((p) => p['harvest_status'] as String? ?? 'NOT_STARTED').toList();

    final allCompleted =
        harvestStatuses.every((s) => s == HarvestStatus.completed.dbValue);
    final anyHarvested = harvestStatuses
        .any((s) => s != HarvestStatus.notStarted.dbValue);

    if (allCompleted) {
      await _setCycleStatus(cycleId, CropStatus.completed,
          completedAt: DateTime.now());
    } else if (anyHarvested) {
      await _setCycleStatus(cycleId, CropStatus.partialHarvest);
    } else {
      // no-op: still ACTIVE
    }

    AppLogger.info(
        'Cycle $cycleId status synced — statuses: $statuses');
  }

  Future<void> _setCycleStatus(
    String cycleId,
    CropStatus status, {
    DateTime? completedAt,
  }) async {
    final data = <String, dynamic>{'status': status.dbValue};
    if (completedAt != null) {
      data['completed_at'] = completedAt.toIso8601String();
    }
    await _db.from('crop_cycles').update(data).eq('id', cycleId);
  }

  Future<void> archiveCycle(String cycleId) =>
      _setCycleStatus(cycleId, CropStatus.archived);

  Future<void> updateCycleName(String cycleId, String name) async {
    await _db
        .from('crop_cycles')
        .update({'name': name}).eq('id', cycleId);
  }
}
