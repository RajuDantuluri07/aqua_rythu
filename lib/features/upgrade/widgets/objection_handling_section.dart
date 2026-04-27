import 'package:flutter/material.dart';

class ObjectionHandlingSection extends StatefulWidget {
  const ObjectionHandlingSection({super.key});

  @override
  State<ObjectionHandlingSection> createState() =>
      _ObjectionHandlingSectionState();
}

class _ObjectionHandlingSectionState extends State<ObjectionHandlingSection> {
  final List<bool> _expandedItems = [false, false, false, false, false];

  final List<Map<String, String>> _objections = [
    {
      'question': 'Will this reduce my feed?',
      'answer':
          'Yes, when the pond data shows overfeeding risk. PRO suggests a safe percentage correction instead of blindly cutting feed.',
    },
    {
      'question': 'Does this work before DOC 30?',
      'answer':
          'Before DOC 30, AquaRythu shows basic feed loss insights. Smart tray-based auto-correction becomes stronger once enough DOC and tray data are available.',
    },
    {
      'question': 'What if tray reading is wrong?',
      'answer':
          'The engine uses conservative correction and avoids extreme jumps. If tray data is missing or unreliable, it falls back to a safer base recommendation.',
    },
    {
      'question': 'Can I use for multiple ponds?',
      'answer':
          'Yes. The crop plan works for the selected crop workflow, and the yearly saver plan is better when you manage 2-3 crops or multiple active ponds.',
    },
    {
      'question': 'Is payment one-time?',
      'answer':
          'The ₹499 plan is one-time per crop. The ₹999 plan gives yearly access for farmers running multiple crops.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.help_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Common Questions",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Q&A Items
          ..._objections.asMap().entries.map((entry) {
            final index = entry.key;
            final objection = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  // Question (Clickable)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expandedItems[index] = !_expandedItems[index];
                      });
                    },
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              objection['question']!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: _expandedItems[index] ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Answer (Expandable)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _expandedItems[index] ? null : 0,
                    child: _expandedItems[index]
                        ? Container(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    objection['answer']!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.8),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
