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

  /// Name in [language]; without any name the ID in readable form instead
  /// of a placeholder (like [Location.displayName]).
  String displayName(String language) =>
      name.values.isNotEmpty ? name(language) : _readableId(id.value);
}

/// `unova-route-4` → "Unova Route 4".
String _readableId(String id) => [
  for (final part in id.split('-'))
    if (part.isNotEmpty) part[0].toUpperCase() + part.substring(1),
].join(' ');

/// Location with its region.
@immutable
class Location {
  const Location({required this.id, required this.name, this.region});

  final LocationId id;
  final LocalizedText name;
  final RegionId? region;

  /// Name in [language]; without any name the ID in readable form
  /// (e.g. `unova-route-4` → "Unova Route 4") instead of a placeholder.
  String displayName(String language) {
    if (name.values.isNotEmpty) return name(language);
    return _readableId(id.value);
  }
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
