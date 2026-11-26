import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_game_rules/mydex_game_rules.dart';

import '../../app/motion.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/evolution_text.dart';
import '../../widgets/motion.dart';
import '../../widgets/type_badge.dart';

/// A titled card section of the detail page.
class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.index = 0,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget child;

  /// Position for the staggered entrance.
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Entrance(
      index: index,
      offset: 24,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.m),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.l,
              Space.l,
              Space.l,
              Space.l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: scheme.primary),
                      const SizedBox(width: Space.s),
                    ],
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: textTheme.titleMedium),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: Space.m),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A form as a small tappable tile (evolution chain, other forms).
class FormTile extends ConsumerWidget {
  const FormTile({super.key, required this.form, required this.current});

  final PokemonForm form;
  final FormId current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final isCurrent = form.id == current;
    final label = catalog.displayName(form)(lang);
    return Semantics(
      button: !isCurrent,
      selected: isCurrent,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          color: isCurrent ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.m),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.m),
            onTap: isCurrent
                ? null
                : () => openPokemon(context, form.id, wide: wide),
            child: Padding(
              padding: const EdgeInsets.all(Space.s),
              child: SizedBox(
                width: 84,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DexThumb(form.id, size: 56),
                    const SizedBox(height: Space.xs),
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isCurrent
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Evolution family: each form with the ways it evolves, left to right.
class EvolutionChain extends ConsumerWidget {
  const EvolutionChain({
    super.key,
    required this.evolutions,
    required this.current,
  });

  final List<ResolvedEvolution> evolutions;
  final FormId current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Group by the form that evolves, in the order of the family.
    final byFrom = <FormId, List<ResolvedEvolution>>{};
    final forms = <FormId, PokemonForm>{};
    for (final e in evolutions) {
      byFrom.putIfAbsent(e.from.id, () => []).add(e);
      forms[e.from.id] = e.from;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, MapEntry(key: from, value: edges))
            in byFrom.entries.indexed) ...[
          if (i > 0) const SizedBox(height: Space.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FormTile(form: forms[from]!, current: current),
              const SizedBox(width: Space.s),
              // Arrows stay compact on wide screens.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in edges)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Space.xs,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: scheme.primary,
                                    ),
                                    Text(
                                      describeEvolution(
                                        e.condition,
                                        l10n,
                                        catalog,
                                        lang,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: Space.s),
                              FormTile(form: e.to, current: current),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Defensive type matchups of a type combination in a ruleset.
class TypeMatchups extends StatelessWidget {
  const TypeMatchups({super.key, required this.types, required this.era});

  final List<PokemonType> types;
  final TypeChartEra era;

  static String _factor(double f) => switch (f) {
    4 => '×4',
    2 => '×2',
    0.5 => '×½',
    0.25 => '×¼',
    0 => '×0',
    _ => '×$f',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = TypeChart.forEra(era);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final valid = [
      for (final t in types)
        if (chart.contains(t)) t,
    ];
    final factors = {
      for (final attacker in chart.types)
        attacker: chart.against(attacker, valid),
    };
    List<MapEntry<PokemonType, double>> where(bool Function(double) test) =>
        factors.entries.where((e) => test(e.value)).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final weak = where((f) => f > 1);
    final resist = where((f) => f > 0 && f < 1)
      ..sort((a, b) => a.value.compareTo(b.value));
    final immune = where((f) => f == 0);

    Widget row(String label, List<MapEntry<PokemonType, double>> list) =>
        Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.s),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final e in list)
                    TypeBadge(e.key, dense: true, trailing: _factor(e.value)),
                ],
              ),
            ],
          ),
        );

    if (weak.isEmpty && resist.isEmpty && immune.isEmpty) {
      return Text(l10n.matchupNeutral);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (weak.isNotEmpty) row(l10n.matchupWeak, weak),
        if (resist.isNotEmpty) row(l10n.matchupResist, resist),
        if (immune.isNotEmpty) row(l10n.matchupImmune, immune),
      ],
    );
  }
}

/// Other forms of the species as a horizontal strip.
class OtherForms extends StatelessWidget {
  const OtherForms({super.key, required this.forms, required this.current});

  final List<PokemonForm> forms;
  final FormId current;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 124,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: forms.length,
      separatorBuilder: (_, _) => const SizedBox(width: Space.s),
      itemBuilder: (context, i) => FormTile(form: forms[i], current: current),
    ),
  );
}

/// Small pill with an icon and text (data source, hints).
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.text,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final String text;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pill = AnimatedContainer(
      duration: Motion.of(context, Motion.short),
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Space.xs + 2),
          Flexible(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}
