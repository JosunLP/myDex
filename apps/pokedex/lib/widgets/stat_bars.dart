import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';

/// Base stats as bars – the numbers are always shown next to them.
class StatBars extends StatelessWidget {
  const StatBars({
    super.key,
    required this.stats,
    required this.unifiedSpecial,
  });

  final BaseStats stats;

  /// Gen 1: one shared Special stat instead of Sp. Atk/Sp. Def.
  final bool unifiedSpecial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <(String, int)>[
      (l10n.statHp, stats.hp),
      (l10n.statAttack, stats.attack),
      (l10n.statDefense, stats.defense),
      if (unifiedSpecial)
        (l10n.statSpecial, stats.specialAttack)
      else ...[
        (l10n.statSpAtk, stats.specialAttack),
        (l10n.statSpDef, stats.specialDefense),
      ],
      (l10n.statSpeed, stats.speed),
    ];
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Semantics(
              label: '$label $value',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(label, style: textTheme.bodyMedium),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.end,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFeatures: tabularFigures,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (value / 255).clamp(0, 1),
                        minHeight: 8,
                        color: _barColor(value, scheme),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Divider(),
        Row(
          children: [
            SizedBox(
              width: 112,
              child: Text(l10n.statTotal, style: textTheme.bodyMedium),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${stats.total(unifiedSpecial: unifiedSpecial)}',
                textAlign: TextAlign.end,
                style: textTheme.bodyMedium?.copyWith(
                  fontFeatures: tabularFigures,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Color _barColor(int v, ColorScheme scheme) => v >= 100
      ? scheme.primary
      : v >= 60
      ? scheme.secondary
      : scheme.tertiary;
}
