import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';

/// Shows the studio language selection modal bottom sheet with script badges.
Future<String?> showLanguageSheet(
  BuildContext context, {
  required AppConfig config,
  String? currentCode,
  String actionLabel = 'Select Audio Model  →',
}) {
  final languages = config.languages;
  int selectedIdx = 0;
  if (currentCode != null) {
    final found = languages.indexWhere((l) => l.code == currentCode);
    if (found != -1) selectedIdx = found;
  }

  String getBadge(String code) {
    if (code == 'bilingual') return 'அ / A';
    if (code.contains('ta')) return 'தமிழ்';
    return 'EN';
  }

  String getSubtitle(String code) {
    if (code == 'bilingual') return 'Best for mixed conversations';
    if (code.contains('ta')) return 'Pure Tamil speech clarity';
    return 'Fast English-only recognition';
  }

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Audio Model',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...List.generate(languages.length, (i) {
                  final lang = languages[i];
                  final active = i == selectedIdx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Tactile(
                      onTap: () => setSheet(() => selectedIdx = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: active
                              ? Palette.emerald.withValues(alpha: 0.10)
                              : Theme.of(ctx).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? Palette.emerald : Theme.of(ctx).dividerColor,
                            width: active ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 44,
                              decoration: BoxDecoration(
                                color: active ? Palette.emerald : Theme.of(ctx).cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  getBadge(lang.code),
                                  style: TextStyle(
                                    color: active ? Colors.white : null,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    getSubtitle(lang.code),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(ctx).hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (active)
                              const Icon(Icons.check_circle, color: Palette.emerald),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Tactile(
                  onTap: () => Navigator.pop(ctx, languages[selectedIdx].code),
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Palette.coral,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Center(
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
