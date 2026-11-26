# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow
[Semantic Versioning](https://semver.org/). Before a release, “Unreleased” is renamed to the new
version; the release workflow takes that section as release notes.

## [Unreleased]

### Added
- **International Pokédex** as the new default: every Pokémon with its newest data, independent
  of a single game – types, base stats and abilities from the newest game that confirms the
  form, evolutions with their newest conditions, moves from the newest core-series learnset.
  The source game is shown. Locations list the games with encounters; one tap switches to a
  game (with undo). Its collection marks are the game-independent list.
- New game picker: searchable sheet (phones) or dialog (desktops) with the International
  Pokédex, recently used games and all games by generation.
- Dex grid view with artwork cards; list or grid is remembered.
- Pokémon page: colour header from the artwork, artwork flies in from the list, swipe to the
  previous/next Pokémon (buttons next to the list on desktops), type matchups (weaknesses,
  resistances, immunities), evolution chain with pictures, other forms as a strip.
- Setting "Reduce motion" in addition to the system setting.
- Own logo and app icons for Android (adaptive, round and themed), iOS, macOS, Windows and
  Linux; branded splash screens (light and dark) and an animated loading screen.
- Linux desktop entry, AppStream metadata and window icon; Windows version information.

### Changed
- Complete visual overhaul: bundled typefaces (Plus Jakarta Sans, JetBrains Mono), calm neutral
  surfaces, cards and rounded shapes, redesigned navigation, collection, teams and settings.
- Motion throughout: fade-through between sections, staggered entrances, animated stat bars,
  progress ring and header colours, confirmation pop with haptics when marking Pokémon.
- The collection list builds lazily (faster with all 1351 forms).
- Without a chosen game the app now opens on the International Pokédex instead of the newest
  game; an explicitly chosen game stays selected.
- macOS: the app bundle is now called `myDex.app`.

## [1.0.0] – 2026-10-27

First version.

### Added
- Pokémon Dex covering all games: forms, types, base stats and abilities per game, evolutions
  with conditions, moves with learnsets and change history.
- Locations per game version; acquisition via evolution, breeding, trading between games and
  events (mythical Pokémon). Data gaps are shown as such, never as “not catchable”.
- Which Pokémon are missing from newer games is derived from complete game data, regional
  Pokédexes and game mechanics (Let's Go to Champions); expansions inherit their base game.
  This reduces data gaps in these games by more than 90 % overall.
- Collection per game and across games, with shiny and catch date; combinable filters and
  presets.
- Teams with stat calculation, validation (valid / partial / insufficient data / invalid), type
  analysis and move suggestions.
- Backup to a file, optionally password-encrypted.
- UI in German, English, French, Spanish and Italian; names in eleven languages.
- Read-aloud via the system's text-to-speech; offline help.
- Optional sync via a self-hosted server, end-to-end encrypted with a sync passphrase; Android
  flavor “sync”.
- Catalog updates via your own sync server, signed with Ed25519 and verified against the key
  built into the app; older snapshots are never installed.
- Gallery with official artwork and images per game: sprites for Gen 1–6 with shiny, from Gen 7
  still images or box icons up to Champions; thumbnails in Dex, collection and teams – fully
  offline.
- Pokédex-style design: muted red casing, lens with signal LEDs, screen with the artwork in
  front of the Pokémon's own colour (derived from the artwork) and a digital number; Dex list,
  collection and teams with small screens in the Pokémon's colour; dark variant.
- Accessibility checked automatically (tap targets, labels, contrast).

### Security and privacy
- No accounts, no analytics, no ads. The default Android flavor has no internet permission
  (checked in CI).
