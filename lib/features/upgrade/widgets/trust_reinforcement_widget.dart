import 'package:flutter/material.dart';

class TrustReinforcementWidget extends StatelessWidget {
  const TrustReinforcementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const points = [
      _TrustPoint(
        Icons.agriculture_rounded,
        'Works for 1-50 acre farms',
      ),
      _TrustPoint(
        Icons.dataset_rounded,
        'Based on real pond data',
      ),
      _TrustPoint(
        Icons.location_on_rounded,
        'Built for Indian shrimp farmers',
      ),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trusted by farmers like you',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      point.icon,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface.withOpacity(0.76),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPoint {
  final IconData icon;
  final String text;

  const _TrustPoint(this.icon, this.text);
}
