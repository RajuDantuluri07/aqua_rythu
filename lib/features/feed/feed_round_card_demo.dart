import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'simple_feed_round_card.dart';

class FeedRoundCardDemo extends ConsumerStatefulWidget {
  const FeedRoundCardDemo({super.key});

  @override
  ConsumerState<FeedRoundCardDemo> createState() => _FeedRoundCardDemoState();
}

class _FeedRoundCardDemoState extends ConsumerState<FeedRoundCardDemo> {
  // Demo data
  final List<Map<String, dynamic>> feedRounds = [
    {
      'round': 1,
      'time': '6:00 AM',
      'feedQty': 8.5,
      'status': FeedRoundStatus.done,
    },
    {
      'round': 2,
      'time': '10:00 AM',
      'feedQty': 9.0,
      'status': FeedRoundStatus.current,
    },
    {
      'round': 3,
      'time': '2:00 PM',
      'feedQty': 9.5,
      'status': FeedRoundStatus.upcoming,
    },
    {
      'round': 4,
      'time': '6:00 PM',
      'feedQty': 10.0,
      'status': FeedRoundStatus.upcoming,
    },
  ];

  int currentDoc = 35; // Demo DOC value

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed Round Card Demo'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DOC selector for demo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Demo Controls",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text("DOC: "),
                      DropdownButton<int>(
                        value: currentDoc,
                        items: [15, 25, 35, 45].map((doc) {
                          return DropdownMenuItem(
                            value: doc,
                            child: Text("$doc days"),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              currentDoc = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Text(
                        currentDoc <= 30 ? "Blind Feeding" : "Smart Feeding",
                        style: TextStyle(
                          color: currentDoc <= 30 ? Colors.orange : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Feed round cards
            ...feedRounds.map((round) {
              return SimpleFeedRoundCard(
                round: round['round'],
                time: round['time'],
                feedQty: round['feedQty'],
                status: round['status'],
                doc: currentDoc,
                onEdit: () {
                  _showEditDialog(round);
                },
                onMarkAsFed: () {
                  _markAsFed(round);
                },
                onTrayCondition: (condition) {
                  _logTrayCondition(round, condition);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> round) {
    final controller = TextEditingController(text: round['feedQty'].toStringAsFixed(1));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Round ${round['round']} Feed"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Adjust feed quantity:"),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Feed (kg)",
                border: OutlineInputBorder(),
                suffixText: "kg",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(controller.text);
              if (newQty != null) {
                setState(() {
                  round['feedQty'] = newQty;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Updated Round ${round['round']} to ${newQty.toStringAsFixed(1)} kg"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _markAsFed(Map<String, dynamic> round) {
    setState(() {
      round['status'] = FeedRoundStatus.done;
      
      // Find the next upcoming round and make it current
      final currentIndex = feedRounds.indexOf(round);
      for (int i = currentIndex + 1; i < feedRounds.length; i++) {
        if (feedRounds[i]['status'] == FeedRoundStatus.upcoming) {
          feedRounds[i]['status'] = FeedRoundStatus.current;
          break;
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Round ${round['round']} marked as fed!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _logTrayCondition(Map<String, dynamic> round, String condition) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Round ${round['round']} tray condition: $condition"),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
