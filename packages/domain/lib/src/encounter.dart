import 'package:meta/meta.dart';

import 'ids.dart';
import 'localized_text.dart';

/// Begegnungsmethode (z. B. Gras, Angel, Geschenk).
@immutable
class EncounterMethod {
  const EncounterMethod({
    required this.id,
    required this.name,
    required this.order,
  });

  final EncounterMethodId id;
  final LocalizedText name;
  final int order;
}

/// Ein Gebiet innerhalb eines Ortes (z. B. ein Höhlenstockwerk).
@immutable
class LocationArea {
  const LocationArea({
    required this.id,
    required this.location,
    required this.name,
  });

  final LocationAreaId id;
  final LocationId location;
  final LocalizedText name;
}

/// Ort mit Region.
@immutable
class Location {
  const Location({required this.id, required this.name, this.region});

  final LocationId id;
  final LocalizedText name;
  final RegionId? region;
}

/// Begegnung einer Form in einer Spielversion, über Slots zusammengefasst.
@immutable
class Encounter {
  const Encounter({
    required this.form,
    required this.area,
    required this.method,
    required this.minLevel,
    required this.maxLevel,
    required this.chance,
    this.conditions = const [],
  });

  final FormId form;
  final LocationAreaId area;
  final EncounterMethodId method;
  final int minLevel;
  final int maxLevel;

  /// Summe der Slot-Wahrscheinlichkeiten in Prozent (bei Geschenken 100).
  final int chance;

  /// Bedingungen wie Tageszeit oder Jahreszeit; leer = immer.
  final List<EncounterConditionId> conditions;
}
