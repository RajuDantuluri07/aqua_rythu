import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'supplement_provider.dart';

/// ================= MAIN SCREEN =================
class SupplementMixScreen extends ConsumerWidget {
  final String pondId;
  const SupplementMixScreen({super.key, required this.pondId});

  void _openAddSheet(BuildContext context, String pondId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddSupplementSheet(pondId: pondId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplements = ref.watch(supplementProvider(pondId));
    final currentDoc = ref.watch(docProvider(pondId));

    final active = supplements
        .where((s) => currentDoc >= s.docFrom && currentDoc <= s.docTo)
        .toList();

    final upcoming =
        supplements.where((s) => currentDoc < s.docFrom).toList();

    final completed =
        supplements.where((s) => currentDoc > s.docTo).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Supplement Mix")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, pondId),
        label: const Text("Add Supplement"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// ACTIVE
          _sectionTitle("ACTIVE PLANS"),
          const SizedBox(height: 10),

          if (active.isEmpty)
            _emptyState("No active plans", "Add a supplement to get started"),

          ...active.map((s) => _activeCard(s, currentDoc)),

          const SizedBox(height: 20),

          /// UPCOMING
          _sectionTitle("UPCOMING"),
          const SizedBox(height: 10),

          if (upcoming.isEmpty)
            _emptyState("No upcoming plans", ""),

          ...upcoming.map((s) => _upcomingCard(s, currentDoc)),

          const SizedBox(height: 20),

          /// COMPLETED
          _sectionTitle("COMPLETED"),
          const SizedBox(height: 10),

          if (completed.isEmpty)
            _emptyState("No completed plans", ""),

          ...completed.map((s) => _completedItem(s)),
        ],
      ),
    );
  }

  /// ================= ACTIVE CARD =================
  Widget _activeCard(Supplement s, int currentDoc) {
    final total = s.docTo - s.docFrom;
    final progress = total == 0 ? 0.0 : (currentDoc - s.docFrom) / total;
    final percent = (progress * 100).clamp(0, 100).toInt();
    final daysLeft = (s.docTo - currentDoc).clamp(0, 999);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text("DOC ${s.docFrom}-${s.docTo}",
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: Text("Rounds: ${_roundsText(s.rounds)}")),
                Expanded(child: Text("$percent% • $daysLeft days left")),
              ],
            ),

            const SizedBox(height: 10),

            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
              color: Colors.green,
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(_itemsText(s.items)),
            ),

            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionBtn(Icons.pause, "Pause"),
                _actionBtn(Icons.edit, "Edit"),
                _actionBtn(Icons.stop, "Stop", isDanger: true),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String text, {bool isDanger = false}) {
    return InkWell(
      onTap: () {},
      child: Column(
        children: [
          Icon(icon, color: isDanger ? Colors.red : Colors.black),
          const SizedBox(height: 4),
          Text(text,
              style: TextStyle(color: isDanger ? Colors.red : Colors.black)),
        ],
      ),
    );
  }

  /// ================= UPCOMING =================
  Widget _upcomingCard(Supplement s, int currentDoc) {
    final daysLeft = s.docFrom - currentDoc;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(s.name),
        subtitle: Text("Starts at DOC ${s.docFrom}"),
        trailing: Text("In $daysLeft days"),
      ),
    );
  }

  /// ================= COMPLETED =================
  Widget _completedItem(Supplement s) {
    return ListTile(
      leading: const Icon(Icons.check_circle, color: Colors.green),
      title: Text(s.name),
      subtitle: Text("Ended at DOC ${s.docTo}"),
      trailing: const Chip(label: Text("Finished")),
    );
  }

  /// ================= COMMON =================
  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.inbox, size: 40, color: Colors.grey),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _roundsText(List<bool> rounds) {
    List<String> r = [];
    for (int i = 0; i < rounds.length; i++) {
      if (rounds[i]) r.add("R${i + 1}");
    }
    return r.join(", ");
  }

  String _itemsText(List<Map<String, String>> items) {
    return items.map((e) => "${e["name"]} - ${e["dose"]}").join("\n");
  }
}

/// ================= ADD SHEET =================
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

  final List<Map<String, String>> items = [
    {"name": "", "dose": ""}
  ];

  List<bool> rounds = [true, false, false, false];
  int selectedScope = 0;

  void _addItem() {
    setState(() => items.add({"name": "", "dose": ""}));
  }

  void _removeItem(int index) {
    setState(() => items.removeAt(index));
  }

  void _save() {
    if (nameController.text.isEmpty ||
        docFromController.text.isEmpty ||
        docToController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields")),
      );
      return;
    }

    final s = Supplement(
      name: nameController.text,
      docFrom: int.parse(docFromController.text),
      docTo: int.parse(docToController.text),
      rounds: rounds,
      items: items,
    );

    ref.read(supplementProvider(widget.pondId).notifier).addSupplement(s);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text("Add Supplement",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),

              const SizedBox(height: 20),

              _label("Supplement Name"),
              _input(nameController, keyboardType: TextInputType.text),

              const SizedBox(height: 12),

              _label("Scope"),
              Wrap(
                spacing: 8,
                children: [
                  _chip("This Pond", 0),
                  _chip("Multiple", 1),
                  _chip("All Ponds", 2),
                ],
              ),

              const SizedBox(height: 12),

              _label("DOC Range"),
              Row(
                children: [
                  Expanded(child: _input(docFromController, keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _input(docToController, keyboardType: TextInputType.number)),
                ],
              ),

              const SizedBox(height: 16),

              _label("Rounds"),
              Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: CheckboxListTile(
                      title: Text("R${i + 1}"),
                      value: rounds[i],
                      onChanged: (v) {
                        setState(() => rounds[i] = v!);
                      },
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label("Mix Details"),
                  TextButton(onPressed: _addItem, child: const Text("+ Add"))
                ],
              ),

              Column(
                children: List.generate(items.length, (index) {
                  return Row(
                    children: [
                      Expanded(
                        child: _input(null,
                            onChanged: (v) => items[index]["name"] = v, keyboardType: TextInputType.text),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _input(null,
                            onChanged: (v) => items[index]["dose"] = v, keyboardType: TextInputType.text),
                      ),
                      IconButton(
                        onPressed: () => _removeItem(index),
                        icon: const Icon(Icons.delete, color: Colors.red),
                      )
                    ],
                  );
                }),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text("Save"),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _chip(String text, int index) {
    return ChoiceChip(
      label: Text(text),
      selected: selectedScope == index,
      onSelected: (_) => setState(() => selectedScope = index),
    );
  }

  Widget _input(TextEditingController? controller,
      {Function(String)? onChanged, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
      ),
    );
  }
}