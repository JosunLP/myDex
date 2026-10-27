import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'type_badge.dart';

/// A move with its data in the current game context.
class MoveRow extends StatelessWidget {
  const MoveRow({
    super.key,
    required this.name,
    required this.profile,
    required this.onTap,
    this.leading,
  });

  final String name;

  /// `null` if there is no data for this game.
  final MoveGameProfile? profile;
  final VoidCallback onTap;
  final String? leading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _build(context, constraints.maxWidth >= 440),
    );
  }

  Widget _build(BuildContext context, bool roomy) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final p = profile;
    String num(int? v) => v?.toString() ?? l10n.valueNone;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Space.s,
          horizontal: Space.xs,
        ),
        child: Row(
          children: [
            if (leading != null)
              SizedBox(
                width: 64,
                child: Text(
                  leading!,
                  style: textTheme.labelMedium?.copyWith(
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
            Expanded(child: Text(name)),
            if (p != null) ...[
              TypeBadge(p.type, dense: true),
              const SizedBox(width: Space.s),
              if (roomy)
                SizedBox(
                  width: 72,
                  child: Text(
                    l10n.damageClass(p.damageClass.name),
                    style: textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(
                width: 72,
                child: Semantics(
                  label:
                      '${l10n.movePower} ${num(p.power)}, ${l10n.moveAccuracy} ${num(p.accuracy)}',
                  excludeSemantics: true,
                  child: Text(
                    '${num(p.power)} / ${num(p.accuracy)}',
                    textAlign: TextAlign.end,
                    style: textTheme.bodySmall?.copyWith(
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
