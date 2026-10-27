import 'package:mydex_domain/mydex_domain.dart';

import 'catalog_details.dart';
import 'catalog_snapshot.dart';

/// Tauschgruppen: Spiele derselben Gruppe können untereinander tauschen.
/// Japanische Erstausgaben bilden eine eigene Gruppe (Sprachgrenze).
/// Spiele ohne Eintrag (z. B. Legenden: Arceus) haben keinen Tauschpartner.
const _tradeGroups = {
  'red-green-japan': 'g1jp',
  'blue-japan': 'g1jp',
  'red-blue': 'g1',
  'yellow': 'g1',
  'gold-silver': 'g2',
  'crystal': 'g2',
  'ruby-sapphire': 'g3',
  'emerald': 'g3',
  'colosseum': 'g3',
  'xd': 'g3',
  'firered-leafgreen': 'g3',
  'diamond-pearl': 'g4',
  'platinum': 'g4',
  'heartgold-soulsilver': 'g4',
  'black-white': 'g5',
  'black-2-white-2': 'g5',
  'x-y': 'g6',
  'omega-ruby-alpha-sapphire': 'g6',
  'sun-moon': 'g7',
  'ultra-sun-ultra-moon': 'g7',
  'lets-go-pikachu-lets-go-eevee': 'lgpe',
  'sword-shield': 'swsh',
  'the-isle-of-armor': 'swsh',
  'the-crown-tundra': 'swsh',
  'brilliant-diamond-shining-pearl': 'bdsp',
  'scarlet-violet': 'sv',
  'the-teal-mask': 'sv',
  'the-indigo-disk': 'sv',
};

/// Gen 1 und 2 tauschen über die Zeitkapsel.
const _linkedGroups = {
  'g1': {'g2'},
  'g2': {'g1'},
};

/// Weitere Beschaffungswege neben Fundorten, Entwicklung und Zucht.
class AcquisitionQueries {
  AcquisitionQueries(this.catalog, this.details);

  final CatalogSnapshot catalog;
  final CatalogDetails details;

  /// Versionen, mit denen [version] tauschen kann (ohne sich selbst).
  List<GameVersion> tradePartners(GameVersionId version) {
    final own = catalog.versions.where((v) => v.id == version).firstOrNull;
    if (own == null) return const [];
    final group = _tradeGroups[own.versionGroupId.value];
    if (group == null) return const [];
    final groups = {group, ...?_linkedGroups[group]};
    return [
      for (final v in catalog.versions)
        if (v.id != version &&
            groups.contains(_tradeGroups[v.versionGroupId.value]))
          v,
    ];
  }

  /// Versionen, in denen [form] laut Fundortdaten vorkommt und aus denen es
  /// sich in das Spiel von [ctx] tauschen lässt. Leer, wenn die Form dort
  /// bestätigt nicht existiert.
  List<GameVersion> tradeSources(FormId form, GameContext ctx) {
    final f = catalog.forms[form];
    if (f == null) return const [];
    if (f.profileFor(ctx.versionGroupId).availability ==
        DataAvailability.confirmedUnavailable) {
      return const [];
    }
    return [
      for (final partner in tradePartners(ctx.versionId))
        if (details.hasEncounterData(partner.id) &&
            f.profileFor(partner.versionGroupId).availability !=
                DataAvailability.confirmedUnavailable &&
            details.encountersOf(form, partner.id).isNotEmpty)
          partner,
    ];
  }

  /// Mysteriöses Pokémon, das es im Spiel gibt: in der Regel nur über Events.
  bool isEventOnly(FormId form, GameContext ctx) {
    final f = catalog.forms[form];
    if (f == null) return false;
    final species = catalog.species[f.speciesId];
    return (species?.mythical ?? false) &&
        f.profileFor(ctx.versionGroupId).availability !=
            DataAvailability.confirmedUnavailable;
  }
}
