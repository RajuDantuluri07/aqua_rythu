import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'supplement_provider.dart';
import 'screens/add_supplement_screen.dart';

class SupplementMixScreen extends ConsumerWidget {
  final String pondId;
  const SupplementMixScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplements = ref.watch(supplementProvider);
    final currentDoc = ref.watch(docProvider(pondId));

    final active = supplements
        .where((s) => currentDoc >= s.startDoc && currentDoc <= s.endDoc)
        .toList();

    final completed = supplements.where((s) => currentDoc > s.endDoc).toList();
    final upcoming = supplements.where((s) => currentDoc < s.startDoc).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 50, bottom: 16),
              title: const Text(
                "Supplement Mix",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Colors.indigo.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "POND 1 • DOC $currentDoc",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          if (supplements.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 🟢 ACTIVE SECTION
                  if (active.isNotEmpty) ...[
                    _buildSectionTitle("ACTIVE NOW", Colors.green, Icons.play_circle_fill_rounded),
                    ...active.map((e) => _SupplementCard(
                          supplement: e, 
                          isActive: true, 
                          ref: ref,
                          currentDoc: currentDoc,
                        )),
                    const SizedBox(height: 24),
                  ],

                  // 🟠 UPCOMING SECTION
                  if (upcoming.isNotEmpty) ...[
                    _buildSectionTitle("UPCOMING", Colors.orange, Icons.schedule_rounded),
                    ...upcoming.map((e) => _SupplementCard(
                          supplement: e, 
                          isActive: false, 
                          ref: ref,
                          currentDoc: currentDoc,
                        )),
                    const SizedBox(height: 24),
                  ],

                  // ⚫ COMPLETED SECTION
                  if (completed.isNotEmpty) ...[
                    _buildSectionTitle("COMPLETED", Colors.grey.shade600, Icons.check_circle_rounded),
                    ...completed.map((e) => _SupplementCard(
                          supplement: e, 
                          isActive: false, 
                          isCompleted: true,
                          ref: ref,
                          currentDoc: currentDoc,
                        )),
                  ],
                ]),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddSupplementScreen(),
            ),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: const Text(
          "Add Mix",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
        ),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.science_outlined, size: 64, color: Colors.indigo.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            "No Supplements Yet",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            "Add supplements to track feeding mixes",
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _SupplementCard extends StatelessWidget {
  final Supplement supplement;
  final bool isActive;
  final bool isCompleted;
  final WidgetRef ref;
  final int currentDoc;

  const _SupplementCard({
    required this.supplement,
    required this.isActive,
    this.isCompleted = false,
    required this.ref,
    required this.currentDoc,
  });

  @override
  Widget build(BuildContext context) {
    final s = supplement;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.shade200,
            width: isActive ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade50.withOpacity(0.5) : (isCompleted ? Colors.grey.shade50 : Colors.white),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.shade100 : (isCompleted ? Colors.grey.shade200 : Colors.orange.shade100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? "ACTIVE" : (isCompleted ? "COMPLETED" : "UPCOMING"),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isActive ? Colors.green.shade800 : (isCompleted ? Colors.grey.shade700 : Colors.orange.shade800),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: s.type == SupplementType.waterMix ? Colors.blue.shade100 : Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s.type == SupplementType.waterMix ? Icons.water_drop_rounded : Icons.grain_rounded, 
                            size: 12, 
                            color: s.type == SupplementType.waterMix ? Colors.blue.shade800 : Colors.purple.shade800
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s.type == SupplementType.waterMix ? "WATER MIX" : "FEED MIX",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: s.type == SupplementType.waterMix ? Colors.blue.shade800 : Colors.purple.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "${s.startDoc} - ${s.endDoc} DOC",
                      style: TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w700, 
                        color: Colors.grey.shade600
                      ),
                    ),
                  ],
                ),
                
                // MENU
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddSupplementScreen(supplement: s),
                        ),
                      );
                    } else if (value == 'delete') {
                       ref.read(supplementProvider.notifier).deleteSupplement(s.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit', 
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18), 
                          SizedBox(width: 8), 
                          Text("Edit")
                        ]
                      )
                    ),
                    const PopupMenuItem(
                      value: 'delete', 
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, size: 18, color: Colors.red), 
                          SizedBox(width: 8), 
                          Text("Delete", style: TextStyle(color: Colors.red))
                        ]
                      )
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE & TIMES
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w900,
                          color: isCompleted ? Colors.grey.shade600 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (s.type == SupplementType.feedMix && s.feedingTimes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: s.feedingTimes.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(e, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                        ],
                      ),
                    )).toList(),
                  )
                else if (s.type == SupplementType.waterMix)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (s.frequencyDays != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 12, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text("Every ${s.frequencyDays} Days", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                            ],
                          ),
                        ),
                      if (s.preferredTime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(s.preferredTime!.name.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                            ],
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // ITEMS
                Text(
                  "MIX COMPONENTS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: s.items.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.science, size: 16, color: isCompleted ? Colors.grey.shade400 : Theme.of(context).primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                e.name, 
                                style: TextStyle(
                                  color: isCompleted ? Colors.grey.shade600 : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15
                                )
                              )
                            ),
                            Text(
                              "${e.dosePerKg} ${e.unit}", 
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: isCompleted ? Colors.grey.shade500 : Colors.black87
                              )
                            ),
                          ],
                        ),
                      ))
                  .toList(),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}