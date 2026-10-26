import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/availability_notice.dart';
import '../../widgets/collection_toggles.dart';
import '../../widgets/evolution_text.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/stat_bars.dart';
import '../../widgets/type_badge.dart';
import 'acquisition_section.dart';
import 'learnset_section.dart';
import 'pokemon_speech.dart';

/// Eigenständige Detailseite für schmale Fenster.
class PokemonDetailPage extends StatelessWidget {
  const PokemonDetailPage({super.key, required this.formId});

  final FormId formId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: const [
        GameContextSelector(),
        SizedBox(width: Space.s),
      ],
    ),
    body: PokemonDetailView(formId: formId),
  );
}

/// Detailinhalt, ausschließlich mit Daten des gewählten Spielkontexts.
class PokemonDetailView extends ConsumerWidget {
  const PokemonDetailView({super.key, required this.formId});

  final FormId formId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    if (!catalog.forms.containsKey(formId)) {
      return Center(child: Text(l10n.noResults(formId.value)));
    }
    final d = ref.watch(queriesProvider).detail(formId, ctx);
    final name = catalog.displayName(d.form).resolve(lang);
    final gameName = ctx.version.name(lang);
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final profile = d.profile;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: textTheme.titleMedium),
          ),
          const SizedBox(height: Space.s),
          child,
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(Space.l),
      children: [
        Text(
          '#${d.species.nationalNumber.toString().padLeft(4, '0')}',
          style: textTheme.labelLarge?.copyWith(fontFeatures: tabularFigures),
        ),
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(name.text, style: textTheme.headlineMedium),
              ),
            ),
            if (name.isFallback)
              Padding(
                padding: const EdgeInsets.only(left: Space.s),
                child: Tooltip(
                  message: l10n.translationMissing(name.language),
                  child: const Icon(Icons.translate, size: 20),
                ),
              ),
            const SizedBox(width: Space.s),
            SpeakButton(
              id: 'pokemon:${d.form.id.value}:${ctx.version.id.value}',
              text: () => pokemonSpeechText(
                d,
                l10n,
                catalog,
                Localizations.localeOf(context).languageCode,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.m),
        CollectionToggles(form: d.form.id),
        if (profile.availability != DataAvailability.confirmedAvailable) ...[
          const SizedBox(height: Space.l),
          AvailabilityNotice(
            availability: profile.availability,
            pokemonName: name.text,
            gameName: gameName,
          ),
        ],
        if (profile.types.isNotEmpty)
          section(l10n.sectionTypes, TypeBadges(profile.types)),
        if (profile.baseStats != null)
          section(
            l10n.sectionStats,
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? 560 : double.infinity,
              ),
              child: StatBars(
                stats: profile.baseStats!,
                unifiedSpecial: ctx.ruleset.unifiedSpecial,
              ),
            ),
          ),
        if (profile.availability == DataAvailability.confirmedAvailable)
          section(
            l10n.sectionAbilities,
            !d.abilitiesApplicable
                ? Text(l10n.abilitiesNotApplicable)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final a in d.abilities)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onTap: () => context.push(
                            '/dex/ability/${Uri.encodeComponent(a.ability.id.value)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          leading: Icon(
                            a.hidden
                                ? Icons.visibility_off_outlined
                                : Icons.bolt,
                          ),
                          title: Text(a.ability.name(lang)),
                          subtitle: a.hidden ? Text(l10n.abilityHidden) : null,
                        ),
                    ],
                  ),
          ),
        section(
          l10n.sectionEvolution,
          d.evolutions.isEmpty
              ? Text(l10n.noEvolution)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in d.evolutions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: Space.s,
                          children: [
                            _FormLink(
                              form: e.from,
                              current: d.form.id,
                              wide: wide,
                            ),
                            const Icon(Icons.arrow_forward, size: 18),
                            _FormLink(
                              form: e.to,
                              current: d.form.id,
                              wide: wide,
                            ),
                            Text(
                              '(${describeEvolution(e.condition, l10n, catalog, lang)})',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (profile.availability != DataAvailability.confirmedUnavailable) ...[
          section(l10n.sectionAcquisition, AcquisitionSection(form: d.form.id)),
          section(l10n.sectionMoves, LearnsetSection(form: d.form.id)),
        ],
        if (d.otherForms.isNotEmpty)
          section(
            l10n.sectionForms,
            Wrap(
              spacing: Space.s,
              children: [
                for (final f in d.otherForms)
                  _FormLink(form: f, current: d.form.id, wide: wide),
              ],
            ),
          ),
      ],
    );
  }
}

class _FormLink extends ConsumerWidget {
  const _FormLink({
    required this.form,
    required this.current,
    required this.wide,
  });

  final PokemonForm form;
  final FormId current;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(readyCatalogProvider);
    final label = catalog.displayName(form)(dataLanguageOf(context, ref));
    if (form.id == current) {
      return Chip(
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    return ActionChip(
      label: Text(label),
      onPressed: () => openPokemon(context, form.id, wide: wide),
    );
  }
}
