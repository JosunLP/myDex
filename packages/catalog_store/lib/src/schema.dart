/// Schema des SQLite-Katalogpakets. Wird von der Pipeline geschrieben und von
/// der App nur gelesen. Änderungen erhöhen [catalogSchemaVersion].
library;

const catalogSchemaVersion = 4;

/// Lernmethoden-Codes in der Tabelle `learnset`.
abstract final class LearnMethodCode {
  static const levelUp = 1;
  static const egg = 2;
  static const tutor = 3;
  static const machine = 4;
}

const catalogSchemaSql = [
  '''CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
  '''CREATE TABLE ruleset(
    id TEXT PRIMARY KEY, generation INTEGER NOT NULL, type_chart_era TEXT NOT NULL,
    stat_formula TEXT NOT NULL, party_size INTEGER NOT NULL,
    has_abilities INTEGER NOT NULL, has_held_items INTEGER NOT NULL,
    has_natures INTEGER NOT NULL, unified_special INTEGER NOT NULL,
    has_breeding INTEGER NOT NULL)''',
  '''CREATE TABLE version_group(
    rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE, generation INTEGER NOT NULL,
    ruleset TEXT NOT NULL REFERENCES ruleset(id), sort INTEGER NOT NULL,
    has_data INTEGER NOT NULL)''',
  '''CREATE TABLE version(
    rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    version_group INTEGER NOT NULL REFERENCES version_group(rid))''',
  '''CREATE TABLE species(
    rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE, national INTEGER NOT NULL,
    generation INTEGER NOT NULL, hatchable INTEGER NOT NULL)''',
  '''CREATE TABLE form(
    rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    species INTEGER NOT NULL REFERENCES species(rid), is_default INTEGER NOT NULL,
    own_name INTEGER NOT NULL, battle_only INTEGER NOT NULL, sort INTEGER NOT NULL)''',
  '''CREATE TABLE ability(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    generation INTEGER NOT NULL)''',
  // pocket: Taschenfach der Quelle; generations: Bitmaske (Bit n = Gen n).
  '''CREATE TABLE item(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    pocket TEXT, generations INTEGER NOT NULL)''',
  '''CREATE TABLE nature(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    increased TEXT, decreased TEXT)''',
  '''CREATE TABLE move(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    generation INTEGER NOT NULL)''',
  '''CREATE TABLE region(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE)''',
  '''CREATE TABLE location(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    region INTEGER)''',
  '''CREATE TABLE location_area(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    location INTEGER NOT NULL REFERENCES location(rid))''',
  '''CREATE TABLE encounter_method(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
    sort INTEGER NOT NULL)''',
  '''CREATE TABLE encounter_condition(rid INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE)''',
  // Begegnungen, zusammengefasst je Form, Version, Gebiet, Methode und Bedingungen.
  '''CREATE TABLE encounter(
    form INTEGER NOT NULL, version INTEGER NOT NULL, area INTEGER NOT NULL,
    method INTEGER NOT NULL, min_level INTEGER NOT NULL, max_level INTEGER NOT NULL,
    chance INTEGER NOT NULL, conditions TEXT NOT NULL,
    PRIMARY KEY(form, version, area, method, conditions)) WITHOUT ROWID''',
  // Mehrsprachige Namen aller Entitäten.
  '''CREATE TABLE name(kind TEXT NOT NULL, ref INTEGER NOT NULL, lang TEXT NOT NULL,
    text TEXT NOT NULL, PRIMARY KEY(kind, ref, lang)) WITHOUT ROWID''',
  // Eigenschaften einer Form je Spielgruppe.
  '''CREATE TABLE form_profile(
    form INTEGER NOT NULL, version_group INTEGER NOT NULL, availability TEXT NOT NULL,
    type1 TEXT, type2 TEXT,
    hp INTEGER, atk INTEGER, def INTEGER, spa INTEGER, spd INTEGER, spe INTEGER,
    special INTEGER, ability1 INTEGER, ability2 INTEGER, ability_hidden INTEGER,
    PRIMARY KEY(form, version_group)) WITHOUT ROWID''',
  '''CREATE TABLE move_profile(
    move INTEGER NOT NULL, version_group INTEGER NOT NULL, availability TEXT NOT NULL,
    type TEXT NOT NULL, damage_class TEXT NOT NULL, power INTEGER, accuracy INTEGER,
    pp INTEGER, priority INTEGER NOT NULL,
    PRIMARY KEY(move, version_group)) WITHOUT ROWID''',
  '''CREATE TABLE learnset(
    form INTEGER NOT NULL, version_group INTEGER NOT NULL, method INTEGER NOT NULL,
    move INTEGER NOT NULL, level INTEGER NOT NULL, method_key TEXT,
    PRIMARY KEY(form, version_group, method, move, level)) WITHOUT ROWID''',
  '''CREATE TABLE machine(version_group INTEGER NOT NULL, move INTEGER NOT NULL,
    item INTEGER NOT NULL, PRIMARY KEY(version_group, move, item)) WITHOUT ROWID''',
  '''CREATE TABLE evolution(
    from_form INTEGER NOT NULL, to_form INTEGER NOT NULL, condition TEXT NOT NULL,
    version_groups TEXT NOT NULL)''',
  '''CREATE TABLE coverage(version_group INTEGER PRIMARY KEY, forms_confirmed INTEGER NOT NULL,
    forms_unavailable INTEGER NOT NULL, forms_gaps INTEGER NOT NULL,
    learnset_entries INTEGER NOT NULL, encounter_entries INTEGER NOT NULL)''',
  // Volltextindex über normalisierte Namen (alle Sprachen).
  '''CREATE VIRTUAL TABLE search USING fts5(
    text, kind UNINDEXED, ref UNINDEXED,
    tokenize = 'unicode61 remove_diacritics 2')''',
];
