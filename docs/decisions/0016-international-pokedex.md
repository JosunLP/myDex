# 0016 – International Pokédex as the default, version-independent context

Status: accepted (extends 0004)

## Context
Until now the newest game was the default context (ADR 0004). The newest games have small
rosters (Champions: about a quarter of all forms), so the app opened on an incomplete Dex. Most
questions ("What type is Clefairy?", "How does Eevee evolve into Leafeon?") do not depend on a
single game; users want the current state across all games.

## Decision
The **International Pokédex** is a game context of its own (`GameVersionId('national')`) and
the default. It is *derived* at load time from the game data (`NationalDex` in
`packages/application`), never stored in the catalog pack, so every catalog update moves it to
the newest state automatically and the pack format stays unchanged.

Derivation rules (each value comes from a real game, never invented):

- **Roster:** every form of the catalog – all of them exist in the franchise.
- **Types and base stats:** together from the newest game with complete data, preferring – in
  this order – games with their own data that confirm the form, other games that confirm it,
  then games with data gaps. Expansions without their own data only repeat their base game and
  are therefore not cited as the source. Forms without any data remain a visible data gap
  (ADR 0005).
- **Abilities:** by the same preference, from games whose ruleset has abilities (Let's Go and
  Legends: Arceus have none).
- **Evolutions:** per evolution (from → to) the conditions of the newest game that has it
  (e.g. Leafeon by Leaf Stone instead of Moss Rock).
- **Learnsets:** the newest game in which the form learns moves by level-up (a core-series
  learnset with level-up, machine, egg and tutor moves); only without one, the newest game with
  any learnset (e.g. spin-offs that list trainable moves only). The UI names that game.
- **Moves:** the newest known values (power, accuracy, PP, type, category).
- **Rules:** newest generation and type chart, modern stat formula, abilities, items, natures
  and breeding; party size 6.
- **Locations:** inherently game-specific. The International Pokédex lists the games with
  encounters and lets the user jump into a game; location pages pick a game.
- **Collection:** marks in the International Pokédex use the existing global scope
  (`GlobalScope`), so they also count in the cross-game checklist.

`CatalogSnapshot.profileOf` and `evolutionsIn` resolve both game and International contexts;
`LoadedCatalog` wraps the details in `NationalCatalogDetails`. The validated raw catalog is
untouched.

## Consequences
- The app opens on the complete Dex with current data; game-specific views remain one tap away.
- Settings without a chosen game (`gameVersion == null`) now mean the International Pokédex.
  An explicitly chosen game stays selected.
- Teams can be built for the International Pokédex; they are checked against the newest rules
  and learnsets.
- The ID `national` is persisted (settings, teams) and must stay stable.
