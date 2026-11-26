
<p align="center">
  <img src="docs/brand/app-icon.png" alt="myDex" width="112">
</p>

<h1 align="center">myDex</h1>

<p align="center"><strong>Your offline Pokédex for every game.</strong></p>

Offline-first Pokémon encyclopedia for Android (including GrapheneOS without Google services),
iOS, Windows, macOS and Linux – one shared Flutter/Dart codebase, local data storage,
game-version-specific data and optional sync.

It opens on the **International Pokédex**: every Pokémon with its newest data, independent of
a single game (ADR 0016). One tap switches to any game for exactly its values.

> Unofficial fan project. Pokémon and all related names are trademarks of their respective
> owners. This project is not affiliated with Nintendo, Game Freak or The Pokémon Company.
> Private app, not intended for public distribution. Rights per source: `data/license_inventory/`.

## Status

Phase 1 – Foundation and vertical slice (done):

- [x] Monorepo structure and Dart workspace
- [x] Domain model: species / variety / form, game context, availability states
- [x] Rules: historical type charts (Gen 1, Gen 2–5, Gen 6+), stat formulas, base team type analysis
- [x] Declarative, validated evolution conditions
- [x] Local cross-language search with ranking and typo tolerance
- [x] Local collection (seen / caught / shiny) with atomic saves
- [x] Adaptive Flutter app (bottom navigation / rail / sidebar), German and English
- [x] CI: formatting, analysis, tests; builds for Linux, Android, Windows, macOS, iOS
- [x] Android release without internet permission and without Google services

Phase 2a – Knowledge catalog (done):

- [x] Reproducible data pipeline (`tools/data_pipeline`) from a pinned PokéAPI snapshot
- [x] SQLite catalog with all games, 1351 forms, moves, abilities, items, learnsets and
      evolutions; names in 11 languages; FTS5 search
- [x] Historical values: types, base stats, abilities and move data per game
- [x] Safe catalog installation: checksum, integrity check, atomic switch, fallback
- [x] App: moves per game, move and ability pages, search, data status and coverage

Phase 2b – Locations and acquisition (done):

- [x] Encounters per version: location, area, method, level, rate, conditions
- [x] Dedicated “Locations” section with locations by region and location pages
- [x] Acquisition on the Pokémon page: locations, evolution, breeding
- [x] Data gaps instead of “not catchable” when a game has no encounter data
- [x] Trading between games and event Pokémon (mythicals); concrete event dates not included

Phase 3a – Teams (done):

- [x] Teams per game, stored locally (atomic; unreadable entries are preserved)
- [x] Members with nickname, level, ability, item, nature, four moves, IVs/EVs (Gen 1–2: DVs/stat exp)
- [x] Calculated stats per ruleset
- [x] Validation: valid / partially checked / insufficient data / invalid (ADR 0009)
- [x] Type analysis with shared weaknesses, coverage gaps and move suggestions

Phase 3b – Collection and backup (done):

- [x] Combinable Dex filters: types (any/all), generation, collection status, default forms only
- [x] Filter presets (stored with versioning)
- [x] Global checklist: progress across all games with games and first catch date
- [x] Export/import of all personal data, optionally encrypted, with preview (ADR 0010)
- [x] Signed catalog updates via your own sync server (ADR 0015)
- [ ] Signed release packages per platform, GrapheneOS test device in acceptance

Phase 4a – Languages, help, speech (done):

- [x] UI in German, English, French, Spanish and Italian, selectable or following the system
- [x] Game data in all eleven catalog languages
- [x] Offline help on game selection, data gaps, search, locations, collection, teams, backup, privacy
- [x] Read-aloud via the system's text-to-speech, also without Google services (ADR 0011)
- [x] Gallery: sprites per game (ADR 0013)

Phase 4b – Optional sync (done):

- [x] Sync of collection, teams and filter presets via a self-hosted server (ADR 0012)
- [x] Outbox, revisions, tombstones for deletions, conflict copies instead of overwriting
- [x] Server with SQLite and a command line for accounts (`tools/sync_server`)
- [x] Android: default flavor `offline` without internet permission, flavor `sync` with sync
- [x] End-to-end encryption with a sync passphrase (ADR 0014)

Phase 5 – Stabilization and release (current):

- [x] Accessibility checked automatically: tap targets, labels, contrast (light/dark, phone/desktop)
- [x] Consistent app name “myDex” on all platforms
- [x] Android release signing via GitHub secrets; CI checks the permissions of the release APKs
- [x] Release workflow: packages for Android, Linux, Windows, macOS and the sync server, with checksums
- [x] Privacy policy, security policy, changelog
- [x] GrapheneOS acceptance checklist (`docs/release/grapheneos-acceptance.md`)
- [x] Gallery: official artwork, default, shiny and in-game images of all generations offline; thumbnails in Dex, collection and teams
- [x] Pokédex design: red casing, lens with signal LEDs, screen with artwork and digital number; dark variant in hinge black
- [ ] Create release keys and store them as secrets, first release, on-device acceptance
- [ ] Sign iOS/macOS/Windows builds (developer accounts)

Phase 6 – Experience and brand (done):

- [x] International Pokédex as the default, version-independent context with the newest data
      (types, stats, abilities, evolutions, core-series learnsets), source game shown
- [x] Design system: Plus Jakarta Sans, neutral surfaces, artwork-coloured headers, motion tokens
- [x] Searchable game picker (sheet/dialog) with the International Pokédex, recent games and
      generations
- [x] Dex as list or grid; detail page with hero flight, swipe to the next Pokémon, animated stat
      bars, type matchups and a visual evolution chain
- [x] Collection with progress ring, team cards, settings in groups, "reduce motion"
- [x] Own logo and app icons on all platforms (adaptive and themed on Android), branded splash
      screens, platform metadata (AppStream, .desktop, Windows version info, macOS bundle)

## Structure

```text
apps/pokedex/           Flutter app (presentation)
packages/domain/        Domain models, IDs, game context – pure Dart
packages/game_rules/    Type charts, stats, team analysis – pure Dart
packages/application/   Use cases, repository interfaces, search
packages/catalog_store/ SQLite catalog: schema, reading, validation, installation
packages/user_store/    Personal data (collection, teams, presets, backup)
packages/sync/          Optional sync: protocol, client, server core
tools/data_pipeline/    Fetch, normalize and validate the source, build the catalog
tools/sync_server/      Self-hosted sync server (SQLite)
data/source_manifests/  Pinned source snapshot with checksums
data/fixtures/          Small test catalog (generated by the pipeline)
docs/                   Architecture, decisions (ADRs), parity matrix, brand
```

Dependency direction: `apps → application → domain/game_rules`; `catalog_store` and
`user_store` implement interfaces from `application`. The domain knows neither Flutter nor a
database.

## Development

```sh
flutter pub get                      # resolves the whole workspace
(cd packages/domain && dart test)   # likewise for every pure Dart package
cd apps/pokedex && flutter test
cd apps/pokedex && flutter run -d linux   # or ios, macos, windows
cd apps/pokedex && flutter run --flavor offline   # Android (or --flavor sync)
```

Brand assets are generated from code (`docs/brand/README.md`):

```sh
cd apps/pokedex && flutter test tool/brand/generate_icons_test.dart && python3 tool/brand/finalize_icons.py
```

Screenshots of the real app for design reviews (not committed – they show Pokémon artwork):

```sh
cd apps/pokedex && flutter test tool/screenshots/screenshots_test.dart --dart-define=OUT=/tmp/shots
```

Rebuild the catalog (downloads the pinned source once into `.dart_tool/`):

```sh
dart run tools/data_pipeline/bin/data_pipeline.dart build
```

This produces `apps/pokedex/assets/catalog/catalog.sqlite.gz` (+ manifest) and the test catalog
in `data/fixtures/`. Then `dart run tools/data_pipeline/bin/data_pipeline.dart media` builds the
media packs (sprites, ADR 0013). The build is deterministic; CI rebuilds and checks that the
committed packs match exactly. Rules and known gaps: ADR 0008.

Data source: [PokéAPI](https://github.com/PokeAPI/pokeapi) (BSD-3-Clause), license notice in the app.

Running your own sync server: `tools/sync_server/README.md`. Releases: `docs/release/README.md`.
Privacy: `PRIVACY.md`. Reporting vulnerabilities: `SECURITY.md`.

See `docs/architecture/overview.md`, `docs/decisions/` and `docs/parity/`.
