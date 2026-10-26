import 'package:meta/meta.dart';

import 'availability.dart';
import 'ids.dart';
import 'localized_text.dart';
import 'pokemon_type.dart';
import 'stats.dart';

/// Grundlegende Art mit nationaler Nummer.
@immutable
class Species {
  const Species({
    required this.id,
    required this.nationalNumber,
    required this.name,
    this.aliases = const [],
    this.hatchable = false,
  });

  factory Species.fromJson(Map<String, Object?> j) => Species(
    id: SpeciesId(j['id']! as String),
    nationalNumber: j['national']! as int,
    name: LocalizedText.fromJson(j['name']! as Map<String, Object?>),
    aliases: [...?(j['aliases'] as List<Object?>?)?.cast<String>()],
  );

  final SpeciesId id;
  final int nationalNumber;
  final LocalizedText name;

  /// Alternative Schreibweisen für die Suche.
  final List<String> aliases;

  /// Ob ihre Entwicklungsfamilie Eier legen kann (Babys wie Pichu eingeschlossen;
  /// nicht bei Familien nur aus „unbekannt“ oder Ditto).
  final bool hatchable;
}

@immutable
class Ability {
  const Ability({required this.id, required this.name});

  factory Ability.fromJson(Map<String, Object?> j) => Ability(
    id: AbilityId(j['id']! as String),
    name: LocalizedText.fromJson(j['name']! as Map<String, Object?>),
  );

  final AbilityId id;
  final LocalizedText name;
}

@immutable
class AbilitySlot {
  const AbilitySlot(this.abilityId, {this.hidden = false});

  factory AbilitySlot.fromJson(Map<String, Object?> j) => AbilitySlot(
    AbilityId(j['id']! as String),
    hidden: (j['hidden'] as bool?) ?? false,
  );

  final AbilityId abilityId;
  final bool hidden;
}

/// Eigenschaften einer Form innerhalb einer Spielgruppe.
@immutable
class FormGameProfile {
  const FormGameProfile({
    required this.availability,
    this.types = const [],
    this.baseStats,
    this.abilities = const [],
  });

  factory FormGameProfile.fromJson(Map<String, Object?> j) => FormGameProfile(
    availability: DataAvailability.parse(j['availability']! as String),
    types: [
      for (final t in (j['types'] as List<Object?>?) ?? const <Object?>[])
        PokemonType.parse(t! as String),
    ],
    baseStats: j['stats'] == null
        ? null
        : BaseStats.fromJson(j['stats']! as Map<String, Object?>),
    abilities: [
      for (final a in (j['abilities'] as List<Object?>?) ?? const <Object?>[])
        AbilitySlot.fromJson(a! as Map<String, Object?>),
    ],
  );

  /// Ob die Form in dieser Spielgruppe existiert.
  final DataAvailability availability;
  final List<PokemonType> types;
  final BaseStats? baseStats;
  final List<AbilitySlot> abilities;

  static const notResearched = FormGameProfile(
    availability: DataAvailability.notResearched,
  );
}

/// Konkrete, spielmechanisch relevante Erscheinungsform einer Art.
@immutable
class PokemonForm {
  const PokemonForm({
    required this.id,
    required this.speciesId,
    required this.isDefault,
    required this.profiles,
    this.name,
    this.aliases = const [],
  });

  factory PokemonForm.fromJson(Map<String, Object?> j) => PokemonForm(
    id: FormId(j['id']! as String),
    speciesId: SpeciesId(j['species']! as String),
    isDefault: (j['default'] as bool?) ?? false,
    name: j['name'] == null
        ? null
        : LocalizedText.fromJson(j['name']! as Map<String, Object?>),
    aliases: [...?(j['aliases'] as List<Object?>?)?.cast<String>()],
    profiles: {
      for (final e in (j['profiles']! as Map<String, Object?>).entries)
        VersionGroupId(e.key): FormGameProfile.fromJson(
          e.value! as Map<String, Object?>,
        ),
    },
  );

  final FormId id;
  final SpeciesId speciesId;
  final bool isDefault;

  /// Eigener Anzeigename (z. B. „Alola-Raichu“); sonst gilt der Artname.
  final LocalizedText? name;
  final List<String> aliases;
  final Map<VersionGroupId, FormGameProfile> profiles;

  /// Fehlt ein Profil, ist das eine Datenlücke – nicht „nicht verfügbar“.
  FormGameProfile profileFor(VersionGroupId group) =>
      profiles[group] ?? FormGameProfile.notResearched;
}
