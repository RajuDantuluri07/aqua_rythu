import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';

class FarmManagementWidget extends ConsumerWidget {
  const FarmManagementWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);
    final farms = farmState.farms;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Farm Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (farms.isEmpty) ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.landscape_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No farms found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to add farm screen
                      },
                      child: const Text('Add First Farm'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ListView.builder(
                shrinkWrap: true,
                itemCount: farms.length,
                itemBuilder: (context, index) {
                  final farm = farms[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: Icon(Icons.agriculture,
                            color: Colors.green.shade700),
                      ),
                      title: Text(
                        farm.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                          '${farm.location} • ${farm.ponds?.length ?? 0} ponds'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          // Handle farm actions
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                const SizedBox(width: 8),
                                const Text('Edit Farm'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'ponds',
                            child: Row(
                              children: [
                                Icon(Icons.water, size: 16),
                                const SizedBox(width: 8),
                                const Text('Manage Ponds'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'users',
                            child: Row(
                              children: [
                                Icon(Icons.people, size: 16),
                                const SizedBox(width: 8),
                                const Text('Manage Users'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Text('Delete Farm',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      // TODO: Navigate to farm details
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
