import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'language_provider.dart';

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final isTelugu = locale.languageCode == 'te';

    return PopupMenuButton<String>(
      onSelected: (code) => ref.read(languageProvider.notifier).change(code),
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _buildItem('te', '🇮🇳  తెలుగు', isTelugu),
        _buildItem('en', '🇬🇧  English', !isTelugu),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              isTelugu ? 'తెలుగు' : 'English',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildItem(
      String value, String label, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_rounded,
                  color: Color(0xFF16A34A), size: 18),
          ],
        ),
      ),
    );
  }
}

/// Variant for non-AppBar headers (dark background not guaranteed).
/// Used in the pond dashboard custom header row.
class LanguageSwitcherDark extends ConsumerWidget {
  const LanguageSwitcherDark({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final isTelugu = locale.languageCode == 'te';

    return PopupMenuButton<String>(
      onSelected: (code) => ref.read(languageProvider.notifier).change(code),
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _buildItem('te', '🇮🇳  తెలుగు', isTelugu),
        _buildItem('en', '🇬🇧  English', !isTelugu),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 15, color: Color(0xFF16A34A)),
            const SizedBox(width: 5),
            Text(
              isTelugu ? 'తెలుగు' : 'English',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down,
                size: 16, color: Color(0xFF16A34A)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildItem(
      String value, String label, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_rounded,
                  color: Color(0xFF16A34A), size: 18),
          ],
        ),
      ),
    );
  }
}
