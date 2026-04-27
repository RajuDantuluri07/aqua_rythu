import 'package:flutter/material.dart';

class UseCaseList extends StatelessWidget {
  const UseCaseList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final useCases = [
      {
        'icon': Icons.search,
        'title': 'Detect overfeeding early',
        'description': 'Get alerts before feed waste becomes costly',
      },
      {
        'icon': Icons.trending_down,
        'title': 'Reduce feed by 5–10%',
        'description': 'Optimize feeding without compromising growth',
      },
      {
        'icon': Icons.insights,
        'title': 'Track shrimp growth vs ideal',
        'description': 'Compare actual performance with targets',
      },
      {
        'icon': Icons.attach_money,
        'title': 'Know profit before harvest',
        'description': 'Real-time profitability calculations',
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Real Results, Not Just Features",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            "Don't just list features — show outcomes.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Use case cards
          ...useCases.map((useCase) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      useCase['icon'] as IconData,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          useCase['title'] as String,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          useCase['description'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
