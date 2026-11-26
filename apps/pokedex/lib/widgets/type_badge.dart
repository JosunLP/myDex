import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/motion.dart';
import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';

/// A type with its colour and always with text (no information by colour alone).
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key, this.dense = false, this.trailing});

  final PokemonType type;
  final bool dense;

  /// Optional extra text, e.g. a damage multiplier (“×2”).
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final color = typeColor(type);
    final on = onTypeColor(color);
    final label = AppLocalizations.of(context).typeName(type.key);
    final style =
        (dense
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelLarge)
            ?.copyWith(color: on, fontWeight: FontWeight.w700, height: 1.2);
    return AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.standard,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Space.s : Space.m + 2,
        vertical: dense ? 2 : 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.12)!, color],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          if (trailing != null) ...[
            SizedBox(width: dense ? 4 : 6),
            Text(
              trailing!,
              style: style?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TypeBadges extends StatelessWidget {
  const TypeBadges(this.types, {super.key, this.dense = false});

  final List<PokemonType> types;
  final bool dense;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: dense ? Space.xs : Space.s,
    runSpacing: Space.xs,
    children: [for (final t in types) TypeBadge(t, dense: dense)],
  );
}
