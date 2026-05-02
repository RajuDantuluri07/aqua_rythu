import '../../features/tray/enums/tray_status.dart';

class TrayLog {
  final String pondId;
  final DateTime time;
  final int doc;
  final int round;
  final List<TrayStatus> trays;
  final Map<int, List<String>>? observations;

  /// True when the tray check was automatically skipped (farmer moved to next
  /// round without logging). Stored as tray_statuses = ['skipped'] in DB.
  final bool isSkipped;

  TrayLog({
    required this.pondId,
    required this.time,
    required this.doc,
    required this.round,
    required this.trays,
    this.observations,
    this.isSkipped = false,
  });

  double? get leftoverPercent {
    if (isSkipped || trays.isEmpty) return null;

    final total = trays.fold<double>(0.0, (sum, tray) {
      switch (tray) {
        case TrayStatus.empty:
          return sum; // 0%
        case TrayStatus.light:
          return sum + 15.0; // ~15%
        case TrayStatus.medium:
          return sum + 40.0; // ~40%
        case TrayStatus.heavy:
          return sum + 70.0; // ~70%
      }
    });

    return total / trays.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'pondId': pondId,
      'time': time.toIso8601String(),
      'doc': doc,
      'round': round,
      'trays': trays.map((e) => e.name).toList(),
      'observations': observations?.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  factory TrayLog.fromJson(Map<String, dynamic> json) {
    return TrayLog(
      pondId: json['pondId'],
      time: DateTime.parse(json['time']),
      doc: json['doc'] ?? 0,
      round: json['round'] ?? 1,
      trays: (json['trays'] as List).map((e) {
        try {
          return TrayStatus.values.byName(e);
        } catch (_) {
          return TrayStatus.light;
        }
      }).toList(),
      observations: (json['observations'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(int.parse(k), List<String>.from(v)),
      ),
    );
  }

  factory TrayLog.fromSupabase(Map<String, dynamic> row) {
    final rawStatuses = List<String>.from(row['tray_statuses'] as List? ?? []);
    final skipped = rawStatuses.length == 1 && rawStatuses.first == 'skipped';
    return TrayLog(
      pondId: row['pond_id'],
      time: DateTime.parse(row['date']),
      doc: row['doc'] ?? 0,
      round: row['round_number'] ?? 1,
      isSkipped: skipped,
      trays: skipped
          ? [] // skipped logs carry no tray data
          : rawStatuses.map((e) {
              try {
                return TrayStatus.values.byName(e);
              } catch (_) {
                // Try migration for old enum values
                return migrateOldTrayStatus(e);
              }
            }).toList(),
      observations: (row['observations'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(int.parse(k), List<String>.from(v as List)),
      ),
    );
  }
}
