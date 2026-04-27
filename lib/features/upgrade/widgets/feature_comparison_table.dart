import 'package:flutter/material.dart';

class FeatureComparisonTable extends StatelessWidget {
  const FeatureComparisonTable({super.key});

  static const _sections = [
    _FeatureSection(
      label: 'SAVE FEED COST',
      icon: Icons.savings_outlined,
      features: [
        _Feature('Basic feed schedule', 'Daily feed plan for early DOC',
            free: true),
        _Feature('Smart feed engine', 'Auto-correct feed from pond data',
            free: false),
        _Feature('Tray correction', 'Reduce feed when leftover appears',
            free: false),
        _Feature('Feed optimization', 'Track extra feed and money loss',
            free: false),
      ],
    ),
    _FeatureSection(
      label: 'GROW FASTER SHRIMP',
      icon: Icons.trending_up_rounded,
      features: [
        _Feature('Basic dashboard', 'View pond status and activity',
            free: true),
        _Feature('Growth intelligence', 'Know when growth is slow or ahead',
            free: false),
        _Feature('ABW tracking', 'Use sampled weight in feed decisions',
            free: false),
        _Feature('Sampling insights', 'Turn sample data into next actions',
            free: false),
      ],
    ),
    _FeatureSection(
      label: 'REDUCE RISK',
      icon: Icons.health_and_safety_outlined,
      features: [
        _Feature('Manual tray logging', 'Record pond appetite', free: true),
        _Feature('Alerts', 'Catch feeding and pond risks early', free: false),
        _Feature('Feed mistake detection', 'Spot overfeeding before it grows',
            free: false),
        _Feature('Profit tracking', 'Connect feed cost to crop outcome',
            free: false),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'What you get with PRO',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Table container
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // Header row
                  _buildHeader(context, primary),

                  // Sections
                  ..._sections.expand((section) => [
                        _buildSectionDivider(context, section),
                        ...section.features.map((feature) {
                          final isLast = feature == section.features.last &&
                              section == _sections.last;
                          return _buildRow(context, feature, primary,
                              isLast: isLast);
                        }),
                      ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primary) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: Border(
          bottom:
              BorderSide(color: theme.colorScheme.outline.withOpacity(0.15)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Feature column header
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  'Feature',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ),

            // FREE column header
            Container(
              width: 1,
              color: theme.colorScheme.outline.withOpacity(0.15),
            ),
            SizedBox(
              width: 72,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'FREE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),

            // PRO column header — glowing highlight
            Container(
              width: 1,
              color: primary.withOpacity(0.3),
            ),
            Container(
              width: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primary, primary.withOpacity(0.85)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PRO',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '★',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context, _FeatureSection section) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.25),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
          bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(section.icon,
                      size: 14,
                      color: theme.colorScheme.primary.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  Text(
                    section.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Keep column widths consistent
          SizedBox(
            width: 73,
            child: Container(
              color:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.25),
            ),
          ),
          Container(
            width: 72,
            color: theme.colorScheme.primary.withOpacity(0.04),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, _Feature feature, Color primary,
      {bool isLast = false}) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.08),
                ),
              ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Feature name + description
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      feature.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feature.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FREE cell
            Container(
              width: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            SizedBox(
              width: 72,
              child: Center(child: _buildFreeIcon(context, feature.free)),
            ),

            // PRO cell — always ✅ with tinted bg
            Container(
              width: 1,
              color: primary.withOpacity(0.2),
            ),
            Container(
              width: 72,
              color: primary.withOpacity(0.04),
              child: Center(child: _buildProIcon(context, primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeIcon(BuildContext context, bool included) {
    if (included) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Color(0xFF16A34A),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade500),
    );
  }

  Widget _buildProIcon(BuildContext context, Color primary) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(Icons.check, size: 14, color: Colors.white),
    );
  }
}

class _FeatureSection {
  final String label;
  final IconData icon;
  final List<_Feature> features;

  const _FeatureSection({
    required this.label,
    required this.icon,
    required this.features,
  });
}

class _Feature {
  final String name;
  final String description;
  final bool free;

  const _Feature(this.name, this.description, {required this.free});
}
