import 'package:meta/meta.dart';

import 'ids.dart';
import 'localized_text.dart';

/// Encounter method (e.g. grass, fishing rod, gift).
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

/// An area within a location (e.g. a cave floor).
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

/// Location with its region.
@immutable
class Location {
  const Location({required this.id, required this.name, this.region});

  final LocationId id;
  final LocalizedText name;
  final RegionId? region;
}

/// Encounter of a form in a game version, aggregated over slots.
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

  /// Sum of the slot rates in percent (100 for gifts).
  final int chance;

  /// Conditions such as time of day or season; empty = always.
  final List<EncounterConditionId> conditions;
}
