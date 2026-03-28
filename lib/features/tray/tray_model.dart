import '../../core/enums/tray_status.dart';

class TrayLog {
  final String pondId;
  final DateTime time;
  final int doc;
  final int round;
  final List<TrayStatus> trays;
  final Map<int, List<String>>? observations;

  TrayLog({
    required this.pondId,
    required this.time,
    required this.doc,
    required this.round,
    required this.trays,
    this.observations,
  });

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
          return TrayStatus.partial;
        }
      }).toList(),
      observations: (json['observations'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(int.parse(k), List<String>.from(v)),
      ),
    );
  }
}
