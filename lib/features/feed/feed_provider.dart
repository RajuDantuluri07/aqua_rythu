import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../growth/growth_provider.dart';
import '../../shared/constants/feed_phase.dart';
import '../tray/tray_provider.dart';
import '../../shared/constants/tray_status.dart';

/// ================= MODEL =================
class FeedEntry {
  final String? id;
  final int doc;            // Day of culture
  final int round;          // R1, R2, R3...
  final double quantity;    // kg
  final String feedType;    // Starter, Grower, Finisher
  final DateTime time;
  final bool wasAdjusted;

  FeedEntry({
    this.id,
    required this.doc,
    required this.round,
    required this.quantity,
    required this.feedType,
    required this.time,
    this.wasAdjusted = false,
  });

  Map<String, dynamic> toMap(String pondId) {
    return {
      'pond_id': pondId,
      'doc': doc,
      'round': round,
      'quantity': quantity,
      'feed_type': feedType,
      'created_at': time.toIso8601String(),
      'was_adjusted': wasAdjusted,
    };
  }

  factory FeedEntry.fromMap(Map<String, dynamic> map) {
    return FeedEntry(
      id: map['id']?.toString(),
      doc: map['doc'] as int,
      round: map['round'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      feedType: map['feed_type'] as String,
      time: DateTime.parse(map['created_at']),
      wasAdjusted: map['was_adjusted'] as bool? ?? false,
    );
  }
}

/// ================= NOTIFIER =================
class FeedNotifier extends FamilyAsyncNotifier<List<FeedEntry>, String> {
  
  @override
  Future<List<FeedEntry>> build(String arg) async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('feed_logs')
        .select()
        .eq('pond_id', arg)
        .order('created_at', ascending: true);
        
    final data = response as List<dynamic>;
    return data.map((e) => FeedEntry.fromMap(e)).toList();
  }

  /// ➕ ADD FEED
  Future<void> addFeed(FeedEntry entry) async {
    final supabase = Supabase.instance.client;
    await supabase.from('feed_logs').insert(entry.toMap(arg));
    ref.invalidateSelf();
    await future; // Wait for refresh
  }

  /// ❌ REMOVE FEED
  Future<void> removeFeed(int index) async {
    final currentList = state.value;
    if (currentList == null || index >= currentList.length) return;
    
    final entry = currentList[index];
    if (entry.id != null) {
      final supabase = Supabase.instance.client;
      await supabase.from('feed_logs').delete().eq('id', entry.id!);
      ref.invalidateSelf();
    }
  }

  /// ✏️ UPDATE FEED
  Future<void> updateFeed(int index, FeedEntry updatedEntry) async {
    final currentList = state.value;
    if (currentList == null || index >= currentList.length) return;

    final entry = currentList[index];
    if (entry.id != null) {
      final supabase = Supabase.instance.client;
      await supabase.from('feed_logs').update(updatedEntry.toMap(arg)).eq('id', entry.id!);
      ref.invalidateSelf();
    }
  }

  /// 🔄 CLEAR ALL
  Future<void> clearAll() async {
    final supabase = Supabase.instance.client;
    await supabase.from('feed_logs').delete().eq('pond_id', arg);
    ref.invalidateSelf();
  }

  /// ================= CALCULATIONS =================

  /// 📊 TOTAL FEED (ALL TIME)
  double get totalFeed =>
      state.value?.fold(0, (sum, e) => sum + e.quantity) ?? 0;

  /// 📊 FEED FOR EXACT DOC
  double totalFeedByDoc(int doc) {
    return (state.value ?? [])
        .where((e) => e.doc == doc)
        .fold(0, (sum, e) => sum + e.quantity);
  }

  /// 📊 CUMULATIVE FEED TILL DOC 🔥
  double cumulativeFeedByDoc(int doc) {
    return (state.value ?? [])
        .where((e) => e.doc <= doc)
        .fold(0, (sum, e) => sum + e.quantity);
  }

  /// 📊 FEED BY ROUND
  double totalFeedByRound(int round) {
    return (state.value ?? [])
        .where((e) => e.round == round)
        .fold(0, (sum, e) => sum + e.quantity);
  }

  /// 📊 FEED BY TYPE
  double totalFeedByType(String type) {
    return (state.value ?? [])
        .where((e) => e.feedType == type)
        .fold(0, (sum, e) => sum + e.quantity);
  }

  /// ================= DATE LOGIC =================

  /// 📅 GET TODAY FEEDS (REAL DATE)
  List<FeedEntry> todayFeeds() {
    final today = DateTime.now();
    
    return (state.value ?? []).where((e) {
      return e.time.year == today.year &&
          e.time.month == today.month &&
          e.time.day == today.day;
    }).toList();
  }

  /// 📅 TODAY TOTAL FEED
  double todayTotalFeed() {
    return todayFeeds()
        .fold(0, (sum, e) => sum + e.quantity);
  }

  /// 📅 GET FEEDS BY DOC
  List<FeedEntry> feedsByDoc(int doc) {
    return (state.value ?? []).where((e) => e.doc == doc).toList();
  }

  /// ================= SORTING =================

  /// 🔽 LATEST FIRST (for UI)
  List<FeedEntry> get sortedFeeds {
    final sorted = [...(state.value ?? [])];
    sorted.sort((a, b) => b.time.compareTo(a.time));
    return sorted;
  }

  /// ================= ANALYTICS =================

  /// 📈 AVG FEED PER DAY
  double get averageFeedPerDay {
    final list = state.value;
    if (list == null || list.isEmpty) return 0;

    final uniqueDocs = list.map((e) => e.doc).toSet().length;
    if (uniqueDocs == 0) return 0;

    return totalFeed / uniqueDocs;
  }

  /// ================= VALIDATION =================

  /// ✅ CHECK IF FEEDING IS ALLOWED
  bool canFeed({
    required FeedPhase phase,
    required bool trayLogged,
  }) {
    // If in Smart Phase, tray log is mandatory
    if (phase == FeedPhase.smart && !trayLogged) return false;
    return true;
  }
}

/// ================= PROVIDER =================
final feedProvider =
    AsyncNotifierProvider.family<FeedNotifier, List<FeedEntry>, String>(
  FeedNotifier.new,
);

/// ================= INTELLIGENT FEEDING =================

/// 🧠 RECOMMENDED FEED BASED ON BIOMASS
final recommendedFeedProvider = Provider.family<double, String>((ref, pondId) {
  final growth = ref.watch(growthProvider(pondId));
  final biomass = growth.biomass;
  final avgWeight = growth.avgWeight;

  if (biomass <= 0) return 0;

  /// 📉 Feed Rate (Percentage of Body Weight)
  double feedRate;

  if (avgWeight < 3.0) feedRate = 0.08;        // 8%
  else if (avgWeight < 5.0) feedRate = 0.06;   // 6%
  else if (avgWeight < 10.0) feedRate = 0.045; // 4.5%
  else if (avgWeight < 15.0) feedRate = 0.035; // 3.5%
  else if (avgWeight < 25.0) feedRate = 0.03;  // 3%
  else feedRate = 0.025;                       // 2.5%

  double baseFeed = biomass * feedRate;

  /// 🔧 APPLY TRAY ADJUSTMENT (Growth Mode)
  final trayLogs = ref.watch(trayProvider(pondId));
  double adjustment = 0.0;

  if (trayLogs.isNotEmpty) {
    final lastLog = trayLogs.last;

    // 1. Check Severe Condition (Safety First)
    int untouchedCount = lastLog.trays.where((t) => t == TrayFill.untouched).length;
    if (untouchedCount >= (lastLog.trays.length / 2)) {
      adjustment = -0.20;
    } else {
      // 2. Calculate Average Score
      double totalScore = 0;
      for (var t in lastLog.trays) {
        if (t == TrayFill.empty) totalScore += 0;
        else if (t == TrayFill.mostlyEaten) totalScore += 1;
        else if (t == TrayFill.halfEaten) totalScore += 2;
        else if (t == TrayFill.untouched) totalScore += 3;
      }
      final avg = totalScore / lastLog.trays.length;

      if (avg <= 0.5) adjustment = 0.10;       // 🚀 Growth Mode
      else if (avg <= 1.5) adjustment = 0.0;   // Normal
      else if (avg <= 2.5) adjustment = -0.10; // Overfed
      else adjustment = -0.20;                 // Severe
    }
  }

  return baseFeed * (1 + adjustment);
});