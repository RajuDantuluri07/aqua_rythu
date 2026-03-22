import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'supplement_provider.dart';

class SupplementMixScreen extends ConsumerWidget {
  final String pondId;
  const SupplementMixScreen({super.key, required this.pondId});

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddSupplementSheet(pondId: pondId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplements = ref.watch(supplementProvider(pondId));
    final currentDoc = ref.watch(docProvider(pondId));

    final active = supplements
        .where((s) => currentDoc >= s.docFrom && currentDoc <= s.docTo)
        .toList();

    final upcoming = supplements.where((s) => currentDoc < s.docFrom).toList();
    final completed = supplements.where((s) => currentDoc > s.docTo).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Supplement Mix")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.add),
        label: const Text("Add New Supplement"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (active.isNotEmpty) ...[
            _sectionTitle("ACTIVE"),
            ...active.map((s) => _activeCard(s, currentDoc)),
          ],
          if (upcoming.isNotEmpty) ...[
            _sectionTitle("UPCOMING"),
            ...upcoming.map((s) => _upcomingCard(s)),
          ],
          if (completed.isNotEmpty) ...[
            _sectionTitle("COMPLETED"),
            ...completed.map((s) => _completedItem(s)),
          ],
        ],
      ),
    );
  }

  Widget _activeCard(Supplement s, int currentDoc) {
    final progress =
        ((currentDoc - s.docFrom) / (s.docTo - s.docFrom)).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("● ● ACTIVE",
                  style: TextStyle(color: Colors.green, fontSize: 12)),
              Text("DOC ${s.docFrom} - ${s.docTo}",
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.name,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: List.generate(4, (i) {
              if (s.rounds[i]) {
                return Chip(
                  label: Text("R${i + 1}"),
                  backgroundColor: Colors.green.shade50,
                );
              }
              return const SizedBox();
            }),
          ),
          const SizedBox(height: 12),
          Text("DOC $currentDoc / ${s.docTo}"),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: s.items.map((item) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['name'] ?? ''),
                  Text(item['dose'] ?? ''),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Text("Pause", style: TextStyle(color: Colors.grey)),
              Text("Edit", style: TextStyle(color: Colors.green)),
              Text("Stop", style: TextStyle(color: Colors.red)),
            ],
          )
        ],
      ),
    );
  }

  Widget _upcomingCard(Supplement s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(s.name),
        subtitle: Text("DOC ${s.docFrom} - ${s.docTo}"),
        trailing: const Chip(
          label: Text("Upcoming"),
          backgroundColor: Colors.orange,
        ),
      ),
    );
  }

  Widget _completedItem(Supplement s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(s.name),
        subtitle: Text("DOC ${s.docFrom} - ${s.docTo}"),
        trailing: const Chip(
          label: Text("Completed"),
          backgroundColor: Colors.grey,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class AddSupplementSheet extends ConsumerStatefulWidget {
  final String pondId;
  const AddSupplementSheet({super.key, required this.pondId});

  @override
  ConsumerState<AddSupplementSheet> createState() =>
      _AddSupplementSheetState();
}

class _AddSupplementSheetState
    extends ConsumerState<AddSupplementSheet> {
  final nameController = TextEditingController();
  final docFromController = TextEditingController();
  final docToController = TextEditingController();
  List<bool> rounds = [true, false, false, false];
  List<Map<String, String>> items = [];

  void addItem() {
    setState(() {
      items.add({"name": "", "dose": ""});
    });
  }

  void removeItem(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  void _save() {
    final name = nameController.text.trim();
    final docFrom = int.tryParse(docFromController.text);
    final docTo = int.tryParse(docToController.text);

    if (name.isEmpty || docFrom == null || docTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    if (docFrom > docTo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("DOC From must be less than DOC To")),
      );
      return;
    }

    final filteredItems = items.where((item) => 
      item['name'] != null && item['name']!.isNotEmpty &&
      item['dose'] != null && item['dose']!.isNotEmpty
    ).toList();

    final s = Supplement(
      name: name,
      docFrom: docFrom,
      docTo: docTo,
      rounds: rounds,
      items: filteredItems,
    );

    ref.read(supplementProvider(widget.pondId).notifier).addSupplement(s);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text("Add Supplement",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: docFromController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "DOC From",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: docToController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "DOC To",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text("Feed Rounds", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(4, (i) {
                          return Expanded(
                            child: CheckboxListTile(
                              value: rounds[i],
                              onChanged: (v) {
                                setState(() => rounds[i] = v!);
                              },
                              title: Text("R${i + 1}"),
                              contentPadding: EdgeInsets.zero,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Mix Details", style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: addItem, 
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add Item"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...items.asMap().entries.map((entry) {
                        int index = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: "Item Name",
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => items[index]['name'] = v,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: "Dosage",
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => items[index]['dose'] = v,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => removeItem(index),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F9D55),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text("Save Supplement", style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    docFromController.dispose();
    docToController.dispose();
    super.dispose();
  }
}