import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';

/// Beschreibt eine Begegnung: Methode, Level, Wahrscheinlichkeit, Bedingungen.
class EncounterDetails extends ConsumerWidget {
  const EncounterDetails({
    super.key,
    required this.encounter,
    this.showArea = false,
  });

  final Encounter encounter;

  /// Gebietsname voranstellen (wenn ein Ort mehrere Gebiete hat).
  final bool showArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final e = encounter;
    final method =
        catalog.encounterMethods[e.method]?.name(lang) ?? e.method.value;
    final levels = e.minLevel == e.maxLevel
        ? '${e.minLevel}'
        : '${e.minLevel}–${e.maxLevel}';
    final area = catalog.locationAreas[e.area];
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showArea && area != null)
          Text(area.name(lang), style: textTheme.labelLarge),
        Text(
          l10n.encounterLine(method, levels, e.chance),
          style: textTheme.bodyMedium?.copyWith(fontFeatures: tabularFigures),
        ),
        if (e.conditions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final c in e.conditions)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      catalog.encounterConditionNames[c]?.call(lang) ?? c.value,
                      style: textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
