import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../l10n/generated/app_localizations.dart';

/// Erzeugt aus der deklarativen Bedingung einen lokalisierten Text.
String describeEvolution(
  EvolutionCondition c,
  AppLocalizations l10n,
  CatalogSnapshot catalog,
  String lang,
) {
  String item(ItemId id) => catalog.itemNames[id]?.call(lang) ?? id.value;
  String sub(EvolutionCondition x) => describeEvolution(x, l10n, catalog, lang);
  String specialValue(String key, String value) => switch (key) {
    'known-move-type' || 'party-type' => l10n.typeName(value),
    'party-species' ||
    'trade-species' => catalog.species[SpeciesId(value)]?.name(lang) ?? value,
    'used-move' => catalog.moves[MoveId(value)]?.name(lang) ?? value,
    'chance' => '$value %',
    _ => value,
  };
  return switch (c) {
    AllOf(:final conditions) => conditions.map(sub).join(l10n.evoAnd),
    AnyOf(:final conditions) => conditions.map(sub).join(l10n.evoOr),
    MinLevel(:final level) => l10n.evoLevel(level),
    UseItem(item: final i) => l10n.evoUseItem(item(i)),
    HoldItem(item: final i) => l10n.evoHoldItem(item(i)),
    TimeOfDayCondition(:final time) => l10n.evoTimeOfDay(time.name),
    AtLocation(:final location) => l10n.evoLocation(
      catalog.locationNames[location]?.call(lang) ?? location.value,
    ),
    InRegion(:final region) => l10n.evoRegion(region),
    MinFriendship(:final value) => l10n.evoFriendship(value),
    KnowsMove(:final move) => l10n.evoKnowsMove(
      catalog.moves[move]?.name(lang) ?? move.value,
    ),
    Trade() => l10n.evoTrade,
    GenderCondition(:final gender) => l10n.evoGender(gender.name),
    SpecialCondition(:final explanationKey, :final value) =>
      value == null
          ? l10n.evoSpecial(explanationKey.replaceAll('-', '_'))
          : l10n.evoSpecialValue(
              l10n.evoSpecial(explanationKey.replaceAll('-', '_')),
              specialValue(explanationKey, value),
            ),
  };
}
