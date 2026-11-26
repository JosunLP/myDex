import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../l10n/generated/app_localizations.dart';

/// Encounter methods and conditions describe game mechanics, so they are
/// app vocabulary in the UI language (like learn methods). The catalog's
/// names are only partly translated (German about a quarter, Spanish and
/// Italian none), so the app translates them itself and falls back to the
/// catalog name in the data language for anything it does not know.

/// Short name of an encounter method, e.g. "Super Rod".
String describeEncounterMethod(
  EncounterMethodId id,
  AppLocalizations l10n,
  CatalogSnapshot catalog,
  String lang,
) {
  final text = l10n.encounterMethod(id.value.replaceAll('-', '_'));
  if (text.isNotEmpty) return text;
  return catalog.encounterMethods[id]?.name(lang) ?? id.value;
}

/// Describes an encounter condition, e.g. "Morning", "Helix Fossil in the
/// Bag" or "At least 10 water block points".
String describeEncounterCondition(
  EncounterConditionId id,
  AppLocalizations l10n,
  CatalogSnapshot catalog,
  String lang,
) {
  if (translateEncounterCondition(id, l10n, catalog, lang) case final text?) {
    return text;
  }
  final name = catalog.encounterConditionNames[id];
  return name == null || name.values.isEmpty ? _readable(id.value) : name(lang);
}

/// The app's own wording of a condition; `null` for the few rare ones it
/// does not know (then the catalog name is used).
String? translateEncounterCondition(
  EncounterConditionId id,
  AppLocalizations l10n,
  CatalogSnapshot catalog,
  String lang,
) {
  final fixed = l10n.encounterCondition(id.value.replaceAll('-', '_'));
  if (fixed.isNotEmpty) return fixed;
  return _parameterized(id.value, l10n, catalog, lang);
}

/// `other-correct-password` → "Other correct password" (never "?").
String _readable(String id) {
  final text = id.replaceAll('-', ' ');
  return text.isEmpty ? id : text[0].toUpperCase() + text.substring(1);
}

String? _parameterized(
  String v,
  AppLocalizations l10n,
  CatalogSnapshot catalog,
  String lang,
) {
  RegExpMatch? match(String pattern) => RegExp('^$pattern\$').firstMatch(v);
  String? pokemon(String key) => switch (catalog.forms[FormId(key)]) {
    final form? => catalog.displayName(form)(lang),
    null => catalog.species[SpeciesId(key)]?.name(lang),
  };
  String? game(String key) =>
      catalog.versionById(GameVersionId(key))?.name(lang);
  String time(String hh, String mm) => '$hh:$mm';

  if (match('item-(.+)') case final m?) {
    final item = catalog.itemNames[ItemId(m[1]!)]?.call(lang);
    return item == null ? null : l10n.conditionItem(item);
  }
  if (match('trade-(.+)') case final m?) {
    final name = pokemon(m[1]!);
    return name == null ? null : l10n.conditionTrade(name);
  }
  // Lists like "regirock-regice-registeel" or "dialga-or-palkia".
  String? pokemonList(String list) {
    final names = <String>[];
    var or = false;
    for (final token in list.split('-')) {
      if (token == 'or') {
        or = true;
        continue;
      }
      final name = pokemon(token);
      if (name == null) return null;
      names.add(name);
    }
    if (names.length < 2) return names.firstOrNull;
    final last = names.removeLast();
    return '${names.join(', ')}${or ? l10n.evoOr : l10n.evoAnd}$last';
  }

  if (match('other-(?:caught|captured)-(.+)') case final m?) {
    final names = pokemonList(m[1]!);
    return names == null ? null : l10n.conditionCaught(names);
  }
  if (match('other-(.+)-in-party') case final m?) {
    final names = pokemonList(m[1]!);
    return names == null ? null : l10n.conditionInParty(names);
  }
  if (match('starter-(.+)') case final m?) {
    final name = pokemon(m[1]!);
    return name == null ? null : l10n.conditionStarter(name);
  }
  if (match('slot2-(.+)') case final m?) {
    final name = game(m[1]!);
    return name == null ? null : l10n.conditionSlot2(name);
  }
  if (match('save-data-from-(.+)') case final m?) {
    final name = game(m[1]!);
    return name == null ? null : l10n.conditionSaveData(name);
  }
  if (match(r'coins-(\d+)') case final m?) {
    return l10n.conditionCoins(int.parse(m[1]!));
  }
  if (match(r'johto-safari-blocks-(forest|water|plains|peak)-min-(\d+)')
      case final m?) {
    return l10n.conditionSafariBlocks(int.parse(m[2]!), m[1]!);
  }
  if (match(r'great-marsh-daily-slot-(\d+)-of-32') case final m?) {
    return l10n.conditionGreatMarsh(int.parse(m[1]!));
  }
  if (match(r'max-den-rating-(\d)-stars?') case final m?) {
    return l10n.conditionMaxRaidStars(int.parse(m[1]!));
  }
  if (match(r'friend-safari-slot-(\d)') case final m?) {
    return l10n.conditionFriendSafari(int.parse(m[1]!));
  }
  if (match(r'alolan-diglett-found-(\d+)') case final m?) {
    return l10n.conditionDiglett(int.parse(m[1]!));
  }
  if (match(r'time-minute-(\d\d)-to-(\d\d)') case final m?) {
    return l10n.conditionMinutes(m[1]!, m[2]!);
  }
  if (match(r'time-(\d\d)-(\d\d)-to-(\d\d)-(\d\d)') case final m?) {
    return l10n.conditionTimeRange(time(m[1]!, m[2]!), time(m[3]!, m[4]!));
  }
  if (match('honey-tree-group-([a-z])') case final m?) {
    return l10n.conditionHoneyTree(m[1]!.toUpperCase());
  }
  if (match('headbutt-tree-(common|rare|secret)') case final m?) {
    return l10n.conditionHeadbuttTree(m[1]!);
  }
  if (match('berry-tree-type-(red|blue|purple|green|yellow|pink)')
      case final m?) {
    return l10n.conditionBerryTree(m[1]!);
  }
  const days = 'monday|tuesday|wednesday|thursday|friday|saturday|sunday';
  if (match('weekday-($days)') case final m?) {
    return l10n.weekdayName(m[1]!);
  }
  if (match('trash-can-type-($days)') case final m?) {
    return l10n.conditionTrashCan(l10n.weekdayName(m[1]!));
  }
  return null;
}
