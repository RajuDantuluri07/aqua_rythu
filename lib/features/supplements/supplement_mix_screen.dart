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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle("ACTIVE"),
          ...active.map((s) => _activeCard(s, currentDoc)),

          _sectionTitle("UPCOMING"),
          ...upcoming.map((s) => _upcomingCard(s)),

          _sectionTitle("COMPLETED"),
          ...completed.map((s) => _completedItem(s)),
        ],
      ),
    );
  }

  Widget _activeCard(Supplement s, int currentDoc) {
    return Card(
      child: ListTile(
        title: Text(s.name),
        subtitle: Text("DOC ${s.docFrom}-${s.docTo}"),
      ),
    );
  }

  Widget _upcomingCard(Supplement s) {
    return ListTile(
      title: Text(s.name),
      subtitle: Text("Upcoming"),
    );
  }

  Widget _completedItem(Supplement s) {
    return ListTile(
      title: Text(s.name),
      subtitle: Text("Completed"),
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

  @override
  void dispose() {
    nameController.dispose();
    docFromController.dispose();
    docToController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text;
    final docFrom = int.tryParse(docFromController.text);
    final docTo = int.tryParse(docToController.text);

    if (name.isEmpty || docFrom == null || docTo == null) return;

    final s = Supplement(
      name: name,
      docFrom: docFrom,
      docTo: docTo,
      rounds: [true, false, false, false],
      items: [],
    );

    ref.read(supplementProvider(widget.pondId).notifier).addSupplement(s);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameController, decoration: const InputDecoration(hintText: "Name")),
          TextField(controller: docFromController, decoration: const InputDecoration(hintText: "DOC From")),
          TextField(controller: docToController, decoration: const InputDecoration(hintText: "DOC To")),
          ElevatedButton(onPressed: _save, child: const Text("Save"))
        ],
      ),
    );
  }
}