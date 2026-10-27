import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/speech.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/evolution_text.dart';

/// Vorlesetext aus Katalogfakten des gewählten Spiels. Spieltexte
/// (Pokédex-Einträge) sind aus Rechtegründen nicht enthalten.
/// Namen folgen der App-Sprache, damit Satz und Aussprache zusammenpassen.
String pokemonSpeechText(
  PokemonDetail d,
  AppLocalizations l10n,
  CatalogSnapshot catalog,
  String lang,
) {
  String nameOf(PokemonForm f) => catalog.displayName(f).resolve(lang).text;
  final name = nameOf(d.form);
  final profile = d.profile;
  final gameName = d.context.version.name(lang);
  final parts = <String>[l10n.speechIntro(name, d.species.nationalNumber)];
  switch (profile.availability) {
    case DataAvailability.confirmedAvailable:
      break;
    case DataAvailability.confirmedUnavailable:
      parts.add(l10n.availabilityConfirmedUnavailable(name, gameName));
    case DataAvailability.notApplicable:
      parts.add(l10n.availabilityNotApplicable(gameName));
    case DataAvailability.unknown:
      parts.add(l10n.availabilityUnknown(gameName));
    case DataAvailability.notResearched:
      parts.add(l10n.availabilityNotResearched(gameName));
  }
  if (profile.types.isNotEmpty) {
    parts.add(
      l10n.speechTypes(
        profile.types.map((t) => l10n.typeName(t.key)).join(l10n.evoAnd),
      ),
    );
  }
  if (profile.availability == DataAvailability.confirmedAvailable &&
      d.abilitiesApplicable &&
      d.abilities.isNotEmpty) {
    parts.add(
      l10n.speechAbilities(
        d.abilities
            .map(
              (a) => a.hidden
                  ? l10n.speechHiddenAbility(a.ability.name(lang))
                  : a.ability.name(lang),
            )
            .join(', '),
      ),
    );
  }
  for (final e in d.evolutions) {
    final condition = describeEvolution(e.condition, l10n, catalog, lang);
    if (e.to.id == d.form.id) {
      parts.add(l10n.speechEvolvesFrom(nameOf(e.from), condition));
    } else if (e.from.id == d.form.id) {
      parts.add(l10n.speechEvolvesInto(nameOf(e.to), condition));
    }
  }
  return parts.join(' ');
}

/// Vorlesen/Stoppen. Ohne Sprachausgabe deaktiviert, mit Hinweis.
/// Verlässt man die Ansicht, endet die Ausgabe.
class SpeakButton extends ConsumerStatefulWidget {
  const SpeakButton({super.key, required this.id, required this.text});

  /// Kennung des Inhalts, damit nur der passende Knopf „Stopp“ zeigt.
  final String id;
  final String Function() text;

  @override
  ConsumerState<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends ConsumerState<SpeakButton> {
  late final SpeechController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(speechProvider.notifier);
  }

  @override
  void dispose() {
    _controller.stopLater(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = ref.watch(speechAvailableProvider).value ?? false;
    final speaking = ref.watch(speechProvider) == widget.id;
    if (!available) {
      return IconButton(
        onPressed: null,
        tooltip: l10n.speechUnavailable,
        icon: const Icon(Icons.volume_off_outlined),
      );
    }
    return IconButton(
      tooltip: speaking ? l10n.speechStop : l10n.speechRead,
      isSelected: speaking,
      icon: const Icon(Icons.volume_up_outlined),
      selectedIcon: const Icon(Icons.stop_circle_outlined),
      onPressed: () => _controller.toggle(
        widget.id,
        widget.text(),
        language: Localizations.localeOf(context).toLanguageTag(),
      ),
    );
  }
}
