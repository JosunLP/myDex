# 0008 – Data source and derivation rules

Status: accepted

## Source
PokéAPI CSV data at a pinned commit (`tools/data_pipeline/lib/src/source.dart`). Every table is
recorded with SHA-256 in `data/source_manifests/pokeapi.json`; a mismatching download aborts the
build. The pipeline is deterministic: same source snapshot → byte-identical pack.

## Rules (game-mechanical facts, no estimates)
- **Historical values:** “*_past” tables apply up to and including their generation; the
  earliest matching entry wins, otherwise the current value (types, base stats, abilities).
- **Gen 1:** a shared Special stat, no abilities. **Hidden abilities** only from Gen 5.
- **Moves:** `move_changelog` holds the values *before* a version group; per field, the earliest
  entry after the version group in question applies. Up to Gen 3 the type determines the damage
  class.
- **Rulesets:** Let's Go and Legends: Arceus without abilities and held items.

## Availability of a form in a version group (ADR 0005)
1. Learnset or encounter data for the form in the version group → **confirmed available**.
2. Species or form introduced later → **confirmed unavailable**.
3. **Expansions** (Isle of Armor, Crown Tundra, Teal Mask, Indigo Disk, Mega Dimension) inherit
   all confirmed statements of their base game.
4. **Regional Pokédex:** if the species is listed in a Pokédex of the version group
   (`pokedex_version_groups`, `pokemon_dex_numbers`) and only one of its forms is a candidate
   (not a battle form, not introduced later) → that form is **confirmed available**. With several
   forms (e.g. Growlithe and Hisuian Growlithe) it stays a gap.
5. **Closed roster:**
   - Let's Go, Sword/Shield, Brilliant Diamond/Shining Pearl, Legends: Arceus and
     Scarlet/Violet: the learnset data was extracted from the game and contains every species in
     the game, including those only obtainable via HOME (verified: 80 species in Sword/Shield, 337
     in Brilliant Diamond/Shining Pearl, 69 in Scarlet/Violet outside their regional Pokédexes).
   - Champions and Legends: Z-A: the roster is the regional Pokédex.
   - A species without data and not in the Pokédex → all its forms **confirmed unavailable**.
     **Exception:** mythical Pokémon, which are partly missing from the data (e.g. Darkrai in
     Brilliant Diamond/Shining Pearl); they stay gaps.
6. **Game mechanics:** Mega and Primal forms only in rulesets with Mega Evolution (Gen 6/7,
   Let's Go, Champions, Legends: Z-A); Gigantamax only in Sword/Shield (with expansions). Battle
   forms of a species that is not in the game are not in the game either.
7. **Game-exclusive forms:** Cosplay Pikachu only in Omega Ruby/Alpha Sapphire, Partner Pikachu
   and Eevee only in Let's Go, Totem forms only in Sun/Moon and Ultra Sun/Ultra Moon.
8. Otherwise → **not yet researched** (data gap). Missing data is never presented as “not in
   the game”.

Rules 3–7 have a rules version (`catalogRules` in the pipeline); it is part of the revision and
the sequence number so that installed apps pick up a re-derived catalog.

## Locations
- Encounters are grouped per form, version, area, method and conditions: lowest/highest level,
  sum of slot rates (at most 100 %).
- Version exclusives follow directly from the version data (e.g. Ekans only in Red).
- If a version has **no** encounter data, the app shows “no location data” – never “not
  catchable”. If only a single form is missing, it says “not included in the location data”.

## Breeding
- Rulesets with breeding: Gen 2–9, excluding Let's Go, Legends: Arceus, Colosseum/XD,
  Legends: Z-A/Mega Dimension and Champions.
- A species counts as hatchable if a member of its evolution family can lay eggs (not only
  “undiscovered”/Ditto). The app mentions breeding only for default forms with confirmed
  availability; the egg hatches as the family's base form. Incense special cases (e.g. Azurill)
  are not modelled – the app makes no statement about them.

## Trading between games
- Trade groups by game generation or game family (Gen 1–7, Let's Go, Sword/Shield with DLC,
  Brilliant Diamond/Shining Pearl, Scarlet/Violet with DLC); Gen 1 and 2 trade via the Time
  Capsule. Japanese first editions form their own group. Legends: Arceus, Legends: Z-A, Mega
  Dimension and Champions have no trade partners. Transfers via Pokémon HOME, Poké Transfer and
  similar are not considered.
- The app says “By trade from …” when a form exists in the selected game but has no locations
  there and occurs in a partner game according to the location data.

## Events
- Mythical Pokémon (`is_mythical` in the source) are marked as event Pokémon if they exist in
  the selected game. The source has no concrete distributions (period, region, code), so the app
  does not name any.

## Evolutions
- Valid from the version group named in the source and from the generation of both species.
- Location-bound evolutions only in version groups whose regions contain the location.
- Regional evolutions (e.g. Pikachu → Alolan Raichu in Alola) replace the general evolution in
  their region.
- Edges to or from confirmed unavailable forms are hidden.

## Known gaps (visible in the data status)
- Pokédex and effect texts are not imported yet.
- The source has no encounter data for, among others, Brilliant Diamond/Shining Pearl, Legends:
  Arceus, Scarlet/Violet (including DLC), Legends: Z-A, Mega Dimension and Champions.
- Concrete event distributions (periods, codes) and transfers between generations are not
  included.
- Many method and condition names exist in the source only in English; the app then shows the
  English name.
- Curse had the type “???” in Gen 2–4, which is not modelled; its values are missing there.
- Shadow moves (Colosseum/XD) are omitted.
- The rulesets of Legends: Z-A, Mega Dimension and Champions are not verified yet and follow the
  modern rules for now. The stat formulas of Let's Go (AVs) and Legends: Arceus (effort levels)
  are not modelled.
- The source contains a duplicate item identifier; the second one gets `--<source ID>`.
