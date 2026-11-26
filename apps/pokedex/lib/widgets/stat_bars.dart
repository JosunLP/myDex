import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/motion.dart';
import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';

/// Base stats as bars – the numbers are always shown next to them.
///
/// The bars grow in one after another and glide to new values when the game
/// changes, so differences between games become visible.
class StatBars extends StatelessWidget {
  const StatBars({
    super.key,
    required this.stats,
    required this.unifiedSpecial,
  });

  final BaseStats stats;

  /// Gen 1: one shared Special stat instead of Sp. Atk/Sp. Def.
  final bool unifiedSpecial;

  /// Colour of a bar by value: low red … high teal (always with the number).
  static Color barColor(int v) => switch (v) {
    < 50 => const Color(0xFFE5534B),
    < 70 => const Color(0xFFF08C3A),
    < 90 => const Color(0xFFF2C14E),
    < 110 => const Color(0xFF8BC34A),
    < 130 => const Color(0xFF3FB27F),
    _ => const Color(0xFF26A6B8),
  };

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
    final total = stats.total(unifiedSpecial: unifiedSpecial);
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = textTheme.bodyMedium?.copyWith(
      fontFeatures: tabularFigures,
      fontWeight: FontWeight.w800,
    );
    // Columns as wide as their text at the current text size, so that
    // values never wrap with large system text.
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double widthOf(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      final width = painter.width.ceilToDouble() + 1;
      painter.dispose();
      return width;
    }

    final valueWidth = widthOf('8' * '$total'.length, valueStyle);
    final labelWidth = math.max(
      104.0,
      [
        for (final (label, _) in rows) label,
        l10n.statTotal,
      ].map((l) => widthOf(l, labelStyle)).reduce(math.max),
    );
    return LayoutBuilder(
      builder: (context, constraints) => _table(
        context,
        rows,
        total,
        labelStyle: labelStyle,
        valueStyle: valueStyle,
        // Labels wrap only when they would leave no room for the bars.
        labelWidth: math.min(labelWidth, constraints.maxWidth * 0.4),
        valueWidth: valueWidth,
      ),
    );
  }

  Widget _table(
    BuildContext context,
    List<(String, int)> rows,
    int total, {
    required TextStyle? labelStyle,
    required TextStyle? valueStyle,
    required double labelWidth,
    required double valueWidth,
  }) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final duration = Motion.of(context, Motion.reveal);
    return Column(
      children: [
        for (final (i, (label, value)) in rows.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Semantics(
              label: '$label $value',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(label, style: labelStyle),
                  ),
                  SizedBox(
                    width: valueWidth,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.end,
                      style: valueStyle,
                    ),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (value / 255).clamp(0, 1)),
                      duration: duration,
                      curve: Interval(
                        (i * 0.07).clamp(0, 0.5),
                        1,
                        curve: Motion.enter,
                      ),
                      builder: (context, t, _) => _Bar(
                        fraction: t,
                        color: barColor(value),
                        track: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Space.s),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: Space.s),
        Row(
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                l10n.statTotal,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              width: valueWidth,
              child: Text(
                '$total',
                textAlign: TextAlign.end,
                style: valueStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) => Container(
    height: 10,
    decoration: BoxDecoration(
      color: track,
      borderRadius: BorderRadius.circular(999),
    ),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: fraction,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [Color.lerp(color, Colors.white, 0.2)!, color],
          ),
        ),
      ),
    ),
  );
}
