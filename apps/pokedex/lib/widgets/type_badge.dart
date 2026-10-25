import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';

/// Typ mit Farbe und immer mit Text (keine Information nur durch Farbe).
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key, this.dense = false});

  final PokemonType type;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = typeColor(type);
    final label = AppLocalizations.of(context).typeName(type.key);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Space.s : Space.m,
        vertical: dense ? 2 : Space.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            (dense
                    ? Theme.of(context).textTheme.labelSmall
                    : Theme.of(context).textTheme.labelLarge)
                ?.copyWith(
                  color: onTypeColor(color),
                  fontWeight: FontWeight.w600,
                ),
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
    spacing: Space.xs,
    runSpacing: Space.xs,
    children: [for (final t in types) TypeBadge(t, dense: dense)],
  );
}
