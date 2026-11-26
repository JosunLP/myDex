# Architecture overview

Summary of the overall design. Binding individual decisions live in `docs/decisions/`.

## Product vision

A fast, privacy-friendly Pokémon encyclopedia for phones and desktops, usable without an
account, with all core features available fully offline. Feature scope at least on the level of
the reference version frozen in `docs/parity/`.

Target platforms: Android, GrapheneOS without Play Services (test target, not a separate port),
iOS, Windows, macOS, Linux.

## Key decisions

1. Flutter/Dart for one shared client codebase (ADR 0001).
2. Local modular monolith; no backend for lookups (ADR 0002).
3. Public catalog and personal data in separate stores (ADR 0003).
4. The game context is passed explicitly through every rule-dependent query (ADR 0004).
5. Missing data is never “not available” – five distinguishable states (ADR 0005).
6. Evolution conditions are declarative data, never scripts (ADR 0006).
7. Catalog as a read-only SQLite pack via `sqlite3` (ADR 0007).
8. Pinned data source and documented derivation rules (ADR 0008).
9. Team validation with four states, without a legality guarantee (ADR 0009).
10. Backup as a versioned, optionally encrypted file (ADR 0010).
11. Read-aloud via the system's text-to-speech, five UI languages (ADR 0011).
12. Optional sync via a self-hosted server (ADR 0012).
13. Sprites as a separate media pack shipped with the app (ADR 0013).
14. Sync end-to-end encrypted with a sync passphrase (ADR 0014).
15. Signed catalog updates via your own sync server (ADR 0015).
16. The version-independent International Pokédex is the default context, derived from the
    newest game data (ADR 0016).

## Layers

| Layer | Package | Contents |
|---|---|---|
| Presentation | `apps/pokedex` | Widgets, navigation, view state |
| Application | `packages/application` | Use cases, repository interfaces, search |
| Domain | `packages/domain`, `packages/game_rules` | Models, rulesets, calculations |
| Infrastructure | `packages/catalog_store`, `packages/user_store`, `packages/sync` | Catalog pack, user data, sync |

Rule: inner layers know nothing about outer ones. Infrastructure implements interfaces from
`application`.

## Data model (core)

- `Species` – species with its national number.
- `Variety` / `Form` – a mechanically relevant appearance with its own stable ID. National Dex
  numbers are not primary keys for forms.
- `GameVersion`, `VersionGroup`, `Ruleset` – game, version group, mechanical rules.
- `FormGameProfile` – types, base stats, abilities and availability of a form in a version
  group. Example: Clefairy is Normal up to Gen 5 and Fairy from Gen 6.
- `EvolutionEdge` with a structured `EvolutionCondition` (AND/OR, level, item, …).
- User data: `CollectionEntry` per scope (game or global), form and shiny flag. Shiny is a
  property, not a form.

## Offline and updates

The core catalog ships with the app so that the first start works without a network.
Updates: signed manifest → temporary download → hash/integrity check → atomic activation →
keep the previous version for rollback. App version, catalog version and user data schema are
three separate versions.

The catalog pack (gzip-compressed SQLite file + manifest with SHA-256) ships with the app and is
installed by `CatalogInstaller` on first start and after app updates. Network updates (ADR 0015)
use the same installer after verifying an Ed25519 signature.

## Data pipeline

`tools/data_pipeline` downloads the required PokéAPI CSV tables of a pinned commit, checks them
against `data/source_manifests/pokeapi.json`, derives game profiles (ADR 0008), builds the
catalog, validates it through the same reader as the app and packs it deterministically.
Coverage per game is shipped as well and shown in the app under “Data status and coverage”.

## Search

Across languages over names, aliases and numbers. Ranking: exact number/exact name → exact
alias → prefix → substring → controlled typo tolerance. Normalization strips diacritics and
unifies ß, ♀/♂ and punctuation.

## Team analysis

Three separate stages: base type analysis (implemented), context-dependent analysis (abilities,
items, weather) and legality checks. Legality results are `valid`, `invalid`,
`partially checked` or `insufficient data` – never an unbacked guarantee.

## Sync (optional)

Self-hosted server (`tools/sync_server`) and client logic in `packages/sync` (ADR 0012). Outbox
per device, account-wide revisions with optimistic concurrency, tombstones for deletions,
conflict copies instead of silent overwrites. HTTPS via a reverse proxy; records are
additionally end-to-end encrypted (ADR 0014). The default Android flavor contains neither sync
nor the internet permission.

## GrapheneOS

Acceptance criterion: works without Google Play Services. No mandatory Google login, Play
Integrity or push; a signed APK in addition to any store; no unnecessary permissions.

## Phases

| Phase | Contents |
|---|---|
| 0 | Reference analysis, parity matrix, rights inventory, platform spikes |
| 1 | Foundation, vertical slice (done) |
| 2 | Complete knowledge catalog: 2a pipeline, moves, abilities, history (done); 2b locations and acquisition (done) |
| 3 | Collection and teams: 3a teams, 3b collection, filters, export/import (done) |
| 4 | Reference parity: 4a languages, help, read-aloud (done); 4b sync (done); gallery (done) |
| 5 | Stabilization and release: accessibility, signing, release workflow, acceptance (in progress) |
