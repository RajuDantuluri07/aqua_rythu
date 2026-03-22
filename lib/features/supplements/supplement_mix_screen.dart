// SAME IMPORTS
// SAME IMPORTS
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
    // Note: We use the generic supplementProvider here. 
    // In a real app with backend, we would use .family(pondId) to fetch specific data.
    final supplements = ref.watch(supplementProvider);
    final currentDoc = ref.watch(docProvider(pondId));

    final active = supplements
        .where((s) => currentDoc >= s.startDoc && currentDoc <= s.endDoc)
        .toList();

    final completed = supplements.where((s) => currentDoc > s.endDoc).toList();
    final upcoming = supplements.where((s) => currentDoc < s.startDoc).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Supplement Mix"),
        elevation: 0,
        backgroundColor: Colors.white,
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
        label: const Text("Add Supplement"),
        icon: const Icon(Icons.add),
      ),
      body: supplements.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                // 🟢 ACTIVE SECTION
                if (active.isNotEmpty) ...[
                  _buildSectionTitle("ACTIVE NOW", Colors.green),
                  ...active.map((e) => _SupplementCard(
                        supplement: e, 
                        isActive: true, 
                        ref: ref
                      )),
                ],

                // 🟠 UPCOMING SECTION
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionTitle("UPCOMING", Colors.orange),
                  ...upcoming.map((e) => _SupplementCard(
                        supplement: e, 
                        isActive: false, 
                        ref: ref
                      )),
                ],

                // ⚫ COMPLETED SECTION
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionTitle("COMPLETED", Colors.grey),
                  ...completed.map((e) => _SupplementCard(
                        supplement: e, 
                        isActive: false, 
                        ref: ref
                      )),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_liquid_outlined, 
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No Supplements Yet",
              style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          const Text("Add supplements to track feeding mixes",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SupplementCard extends StatelessWidget {
  final Supplement supplement;
  final bool isActive;
  final WidgetRef ref;

  const _SupplementCard({
    required this.supplement,
    required this.isActive,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final s = supplement;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isActive ? Colors.green.withOpacity(0.5) : Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? "ACTIVE" : s.getStatus(0).name.toUpperCase(), // 0 is dummy doc here
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ),
              Text("${s.startDoc} - ${s.endDoc} DOC",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              
              // MENU
              PopupMenuButton(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
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
                  const PopupMenuItem(value: 'edit', child: Text("Edit")),
                  const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            s.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            children:
                s.feedingTimes.map((e) => Chip(
                  label: Text(e, style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.grey.shade50,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                )).toList(),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Column(
            children: s.items
                .map((e) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.name, style: const TextStyle(color: Colors.black87)),
                        Text("${e.dosePerKg} ${e.unit}", 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ))
                .toList(),
          )
        ],
      ),
    );
  }
}