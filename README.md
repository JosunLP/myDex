# myDex

Offline-first Pokémon-Enzyklopädie für Android (inkl. GrapheneOS ohne Google-Dienste), iOS,
Windows, macOS und Linux – eine gemeinsame Flutter/Dart-Codebase, lokale Datenhaltung,
spielversionsabhängige Daten und optionaler Sync.

> Inoffizielles Fanprojekt. Pokémon und alle zugehörigen Namen sind Marken ihrer jeweiligen
> Inhaber. Dieses Projekt ist nicht mit Nintendo, Game Freak oder The Pokémon Company verbunden.
> Medien werden erst nach geklärter Rechtelage aufgenommen (siehe `data/license_inventory/`).

## Stand

Phase 1 – Fundament und vertikaler Durchstich:

- [x] Monorepo-Struktur und Dart-Workspace
- [x] Domänenmodell: Art / Variante / Form, Spielkontext, Verfügbarkeitszustände
- [x] Regelwerk: historische Typentabellen (Gen 1, Gen 2–5, ab Gen 6), Statuswertformeln, Basistypen-Teamanalyse
- [x] Deklarative, validierte Entwicklungsbedingungen
- [x] Lokale, sprachübergreifende Suche mit Ranking und Tippfehlertoleranz
- [x] Katalog als gebündeltes Datenpaket (Fixture) – funktioniert beim ersten Start offline
- [x] Lokale Sammlung (gesehen / gefangen / Shiny) mit atomarem Speichern
- [x] Adaptive Flutter-App (Bottom Navigation / Rail / Sidebar), Deutsch und Englisch
- [x] CI: Formatierung, Analyse, Tests; Builds für Linux, Android, Windows, macOS, iOS
- [x] Android-Release ohne Internet-Berechtigung und ohne Google-Dienste
- [ ] SQLite/Drift-Katalog mit FTS5 (ersetzt das JSON-Paket hinter derselben Schnittstelle)
- [ ] Datenpipeline (`tools/data_pipeline`) und signierte Katalogupdates
- [ ] Signierte Release-Pakete je Plattform, GrapheneOS-Testgerät in der Abnahme

## Struktur

```text
apps/pokedex/           Flutter-App (Presentation)
packages/domain/        Fachmodelle, IDs, Spielkontext – reines Dart
packages/game_rules/    Typentabellen, Statuswerte, Teamanalyse – reines Dart
packages/application/   Anwendungsfälle, Repository-Schnittstellen, Suche
packages/catalog_store/ Lesen des Katalogpakets (Validierung, Mapping)
packages/user_store/    Persönliche Daten (Sammlung), getrennt vom Katalog
data/fixtures/          Kleiner, geprüfter Beispielkatalog
docs/                   Architektur, Entscheidungen (ADRs), Paritätsmatrix
```

Abhängigkeitsrichtung: `apps → application → domain/game_rules`; `catalog_store` und
`user_store` implementieren Schnittstellen aus `application`. Die Domäne kennt weder Flutter
noch eine Datenbank.

## Entwicklung

```sh
flutter pub get                      # löst den gesamten Workspace auf
(cd packages/domain && dart test)   # usw. für jedes reine Dart-Paket
cd apps/pokedex && flutter test
cd apps/pokedex && flutter run -d linux   # oder android, ios, macos, windows
```

Beispielkatalog ändern: `tools/fixture_gen/generate_fixture.py` anpassen, ausführen und
`data/fixtures/catalog.json` nach `apps/pokedex/assets/catalog/` kopieren (CI prüft beides).

Siehe `docs/architecture/overview.md`, `docs/decisions/` und `docs/parity/`.
