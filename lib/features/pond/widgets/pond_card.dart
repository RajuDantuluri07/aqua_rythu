import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pond_card_data.dart';
import '../providers/pond_card_provider.dart';
import '../../farm/farm_provider.dart';
import '../../../routes/app_routes.dart';

// ── Status colours ────────────────────────────────────────────────────────────
const _goodColor = Color(0xFF16A34A);
const _attentionColor = Color(0xFFF59E0B);
const _riskColor = Color(0xFFDC2626);

Color _statusColor(String status) {
  switch (status) {
    case 'Risk':
      return _riskColor;
    case 'Attention':
      return _attentionColor;
    default:
      return _goodColor;
  }
}

// ── Public widget ─────────────────────────────────────────────────────────────

/// Pond card for the home screen.
/// Loads its own feed intelligence via [pondCardProvider].
class PondCard extends ConsumerWidget {
  final Pond pond;

  const PondCard({super.key, required this.pond});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pondCardProvider(pond.id));

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.pondDashboard,
        arguments: pond.id,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: async.when(
            loading: () => _Skeleton(pondName: pond.name),
            error: (_, __) => _MinimalCard(pond: pond),
            data: (data) => _CardBody(data: data),
          ),
        ),
      ),
    );
  }
}

// ── Full card body ────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final PondCardData data;

  const _CardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(data.status);

    // Stack: content sets card height; Positioned strip fills it.
    // Avoids IntrinsicHeight which breaks with unbounded-height parents.
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(19, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(data: data, color: color),
              const SizedBox(height: 12),
              _FeedDecision(data: data, color: color),
              const SizedBox(height: 12),
              const _Divider(),
              const SizedBox(height: 10),
              _ContextStats(data: data),
              const SizedBox(height: 10),
              const _Divider(),
              const SizedBox(height: 10),
              _InsightRow(data: data),
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(width: 5, color: color),
        ),
      ],
    );
  }
}

// ── Header: status dot + name + badge ────────────────────────────────────────

class _Header extends ConsumerWidget {
  final PondCardData data;
  final Color color;

  const _Header({required this.data, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            data.pondName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            data.status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ),
        // 3-dot menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF9CA3AF)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 16, color: Color(0xFF374151)),
                  SizedBox(width: 10),
                  Text('Edit Pond', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 10),
                  Text('Delete',
                      style: TextStyle(fontSize: 14, color: Color(0xFFDC2626))),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') _onEdit(context);
            if (value == 'delete') _onDelete(context, ref);
          },
        ),
      ],
    );
  }

  void _onEdit(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.editPond, arguments: data.pondId);
  }

  void _onDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Pond'),
        content: Text('Delete "${data.pondName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final farmState = ref.read(farmProvider);
              final farm = farmState.farms.cast<Farm?>().firstWhere(
                    (f) => f!.ponds.any((p) => p.id == data.pondId),
                    orElse: () => null,
                  );
              if (farm != null) {
                await ref
                    .read(farmProvider.notifier)
                    .deletePond(farm.id, data.pondId);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Feed decision section ─────────────────────────────────────────────────────

class _FeedDecision extends StatelessWidget {
  final PondCardData data;
  final Color color;

  const _FeedDecision({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Feed today (BIG) — label above, value below to avoid overflow at 120px
        const Text(
          'Feed Today',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${data.suggestedFeed.toStringAsFixed(1)} kg',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),

        // Suggestion
        Row(
          children: [
            const Text('👉 ', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Text(
                data.suggestionText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: data.isSmartMode && data.percentChange.abs() > 1
                      ? color
                      : const Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Money + confidence stacked (narrow card friendly)
        _Pill(
          icon: '💰',
          label: data.moneySavedLabel,
          color: data.moneySaved > 0
              ? _goodColor
              : data.moneySaved < 0
                  ? _riskColor
                  : const Color(0xFF6B7280),
        ),
        const SizedBox(height: 4),
        _Pill(
          icon: '📊',
          label: 'Conf: ${data.confidence}',
          color: _confidenceColor(data.confidence),
        ),
      ],
    );
  }

  Color _confidenceColor(String c) {
    switch (c) {
      case 'High':
        return _goodColor;
      case 'Medium':
        return _attentionColor;
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}

class _Pill extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Context stats: DOC, ABW, Density, Survival ───────────────────────────────

class _ContextStats extends StatelessWidget {
  final PondCardData data;

  const _ContextStats({required this.data});

  @override
  Widget build(BuildContext context) {
    final abwText = data.abw > 0 ? '${data.abw.toStringAsFixed(1)} g' : '—';
    final densityText = '${data.density.toStringAsFixed(1)} L/ac';
    final survivalText = '${data.survival.toStringAsFixed(0)}%';

    // 2×2 grid so each stat has enough room in narrow cards
    return Column(
      children: [
        Row(
          children: [
            _Stat(label: 'DOC', value: '${data.doc}'),
            _Stat(label: 'ABW', value: abwText),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _Stat(label: 'Density', value: densityText),
            _Stat(label: 'Survival', value: survivalText),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insight row: Tray, Growth, FCR ───────────────────────────────────────────

class _InsightRow extends StatelessWidget {
  final PondCardData data;

  const _InsightRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final fcrText = data.fcr > 0 ? data.fcr.toStringAsFixed(2) : '—';
    return Row(
      children: [
        _InsightChip(label: 'Tray', value: data.trayResult),
        const SizedBox(width: 8),
        _InsightChip(label: 'Growth', value: data.growthLabel),
        const SizedBox(width: 8),
        _InsightChip(label: 'FCR', value: fcrText),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  final String label;
  final String value;

  const _InsightChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton (loading) ────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  final String pondName;

  const _Skeleton({required this.pondName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBox(width: 9, height: 9, isCircle: true),
              const SizedBox(width: 8),
              Text(
                pondName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SkeletonBox(width: 160, height: 32),
          const SizedBox(height: 8),
          const _SkeletonBox(width: double.infinity, height: 14),
          const SizedBox(height: 12),
          const _SkeletonBox(width: double.infinity, height: 14),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final bool isCircle;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: isCircle ? null : BorderRadius.circular(6),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

// ── Fallback minimal card (error state) ──────────────────────────────────────

class _MinimalCard extends StatelessWidget {
  final Pond pond;

  const _MinimalCard({required this.pond});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.water, color: Color(0xFF6B7280), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pond.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const Text(
            'Tap to open',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6));
  }
}
