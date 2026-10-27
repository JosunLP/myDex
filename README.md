# myDex

Offline-first Pokémon-Enzyklopädie für Android (inkl. GrapheneOS ohne Google-Dienste), iOS,
Windows, macOS und Linux – eine gemeinsame Flutter/Dart-Codebase, lokale Datenhaltung,
spielversionsabhängige Daten und optionaler Sync.

> Inoffizielles Fanprojekt. Pokémon und alle zugehörigen Namen sind Marken ihrer jeweiligen
> Inhaber. Dieses Projekt ist nicht mit Nintendo, Game Freak oder The Pokémon Company verbunden.
> Private App, nicht zur öffentlichen Verbreitung bestimmt. Rechte je Quelle: `data/license_inventory/`.

## Stand

Phase 1 – Fundament und vertikaler Durchstich (abgeschlossen):

- [x] Monorepo-Struktur und Dart-Workspace
- [x] Domänenmodell: Art / Variante / Form, Spielkontext, Verfügbarkeitszustände
- [x] Regelwerk: historische Typentabellen (Gen 1, Gen 2–5, ab Gen 6), Statuswertformeln, Basistypen-Teamanalyse
- [x] Deklarative, validierte Entwicklungsbedingungen
- [x] Lokale, sprachübergreifende Suche mit Ranking und Tippfehlertoleranz
- [x] Lokale Sammlung (gesehen / gefangen / Shiny) mit atomarem Speichern
- [x] Adaptive Flutter-App (Bottom Navigation / Rail / Sidebar), Deutsch und Englisch
- [x] CI: Formatierung, Analyse, Tests; Builds für Linux, Android, Windows, macOS, iOS
- [x] Android-Release ohne Internet-Berechtigung und ohne Google-Dienste

Phase 2a – Wissenskatalog (abgeschlossen):

- [x] Reproduzierbare Datenpipeline (`tools/data_pipeline`) aus einem festgehaltenen PokéAPI-Stand
- [x] SQLite-Katalog mit allen Spielen, 1351 Formen, Attacken, Fähigkeiten, Items, Erlernbarkeit
      und Entwicklungen; Namen in 11 Sprachen; FTS5-Suche
- [x] Historische Werte: Typen, Basiswerte, Fähigkeiten und Attackenwerte je Spiel
- [x] Sichere Katalog-Installation: Prüfsumme, Integritätstest, atomarer Wechsel, Rückfall
- [x] App: Attacken je Spiel, Attacken- und Fähigkeitsseiten, Suche, Datenstand und Abdeckung

Phase 2b – Fundorte und Beschaffung (abgeschlossen):

- [x] Begegnungen je Version: Ort, Gebiet, Methode, Level, Wahrscheinlichkeit, Bedingungen
- [x] Eigener Bereich „Fundorte“ mit Orten nach Region und Ortsseiten
- [x] Beschaffung auf der Pokémon-Seite: Fundorte, Entwicklung, Zucht
- [x] Datenlücken statt „nicht fangbar“, wenn ein Spiel keine Fundortdaten hat
- [ ] Event-Verteilungen und Tausch zwischen Spielen

Phase 3a – Teams (abgeschlossen):

- [x] Teams je Spiel, lokal gespeichert (atomar, unlesbare Einträge bleiben erhalten)
- [x] Mitglieder mit Spitzname, Level, Fähigkeit, Item, Wesen, vier Attacken, IVs/EVs (Gen 1–2: DVs/Status-EP)
- [x] Berechnete Werte je Regelwerk
- [x] Prüfung: gültig / teilweise geprüft / Datenlage unzureichend / ungültig (ADR 0009)
- [x] Typanalyse mit gemeinsamen Schwächen, Abdeckungslücken und Attackenvorschlägen

Phase 3b – Sammlung und Datensicherung (abgeschlossen):

- [x] Kombinierbare Dex-Filter: Typen (einer/alle), Generation, Sammlungsstatus, nur Standardformen
- [x] Filtervorlagen (versioniert gespeichert)
- [x] Globale Checkliste: Fortschritt über alle Spiele mit Spielen und erstem Fangdatum
- [x] Export/Import aller persönlichen Daten, optional verschlüsselt, mit Vorschau (ADR 0010)
- [ ] Signiertes Manifest und Updates über das Netz (bisher nur mitgelieferte Pakete)
- [ ] Signierte Release-Pakete je Plattform, GrapheneOS-Testgerät in der Abnahme

Phase 4a – Sprachen, Hilfe, Vorlesen (abgeschlossen):

- [x] Oberfläche auf Deutsch, Englisch, Französisch, Spanisch und Italienisch, wählbar oder nach System
- [x] Spieldaten in allen elf Katalogsprachen
- [x] Offline-Hilfe zu Spielauswahl, Datenlücken, Suche, Fundorten, Sammlung, Teams, Sicherung, Datenschutz
- [x] Vorlesen über die Sprachausgabe des Systems, auch ohne Google-Dienste (ADR 0011)
- [x] Galerie: Sprites je Spiel (ADR 0013)

Phase 4b – Optionaler Sync (abgeschlossen):

- [x] Abgleich von Sammlung, Teams und Filtervorlagen über einen selbst gehosteten Server (ADR 0012)
- [x] Outbox, Revisionen, Grabsteine für Löschungen, Konfliktkopien statt Überschreiben
- [x] Server mit SQLite und Kommandozeile für Konten (`tools/sync_server`)
- [x] Android: Standardausgabe `offline` ohne Internet-Berechtigung, Ausgabe `sync` mit Abgleich
- [x] Ende-zu-Ende-Verschlüsselung mit Sync-Passwort (ADR 0014)

Phase 5 – Stabilisierung und Veröffentlichung (dieser Stand):

- [x] Barrierefreiheit automatisch geprüft: Tippflächen, Beschriftungen, Kontrast (hell/dunkel, Smartphone/Desktop)
- [x] Einheitlicher App-Name „myDex“ auf allen Plattformen
- [x] Android-Release-Signatur über GitHub-Secrets; CI prüft die Berechtigungen der Release-APKs
- [x] Release-Workflow: Pakete für Android, Linux, Windows, macOS und den Sync-Server, mit Prüfsummen
- [x] Datenschutzerklärung, Sicherheitsrichtlinie, Changelog
- [x] Abnahmeprotokoll für GrapheneOS (`docs/release/grapheneos-abnahme.md`)
- [x] Galerie: offizielles Artwork, Standard-, Shiny- und Spiel-Sprites (Gen 1–5) offline; Vorschaubilder in Dex, Sammlung und Teams
- [x] Pokédex-Gestaltung: rotes Gehäuse, Linse mit Signal-LEDs, Anzeige mit Artwork und Digitalnummer; dunkle Variante in Scharnier-Schwarz
- [ ] Release-Schlüssel erzeugen und als Secrets hinterlegen, erstes Release, Abnahme auf dem Gerät
- [ ] iOS/macOS/Windows signieren (Entwicklerkonten)

## Struktur

```text
apps/pokedex/           Flutter-App (Presentation)
packages/domain/        Fachmodelle, IDs, Spielkontext – reines Dart
packages/game_rules/    Typentabellen, Statuswerte, Teamanalyse – reines Dart
packages/application/   Anwendungsfälle, Repository-Schnittstellen, Suche
packages/catalog_store/ SQLite-Katalog: Schema, Lesen, Prüfen, Installieren
packages/user_store/    Persönliche Daten (Sammlung, Teams, Vorlagen, Sicherung)
packages/sync/          Optionaler Abgleich: Protokoll, Client, Serverkern
tools/data_pipeline/    Quellstand laden, normalisieren, prüfen, Katalog bauen
tools/sync_server/      Selbst gehosteter Sync-Server (SQLite)
data/source_manifests/  Festgehaltener Quellstand mit Prüfsummen
data/fixtures/          Kleiner Testkatalog (von der Pipeline erzeugt)
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
cd apps/pokedex && flutter run -d linux   # oder ios, macos, windows
cd apps/pokedex && flutter run --flavor offline   # Android (oder --flavor sync)
```

Katalog neu bauen (lädt den festgehaltenen Quellstand einmalig nach `.dart_tool/`):

```sh
dart run tools/data_pipeline/bin/data_pipeline.dart build
```

Das erzeugt `apps/pokedex/assets/catalog/catalog.sqlite.gz` (+ Manifest) und den Testkatalog in
`data/fixtures/`. Danach baut `dart run tools/data_pipeline/bin/data_pipeline.dart media` die
Medienpakete (Sprites, ADR 0013). Der Build ist deterministisch; die CI baut neu und prüft, dass die
eingecheckten Pakete exakt übereinstimmen. Regeln und bekannte Lücken: ADR 0008.

Datenquelle: [PokéAPI](https://github.com/PokeAPI/pokeapi) (BSD-3-Clause), Lizenzhinweis in der App.

Sync-Server selbst betreiben: `tools/sync_server/README.md`. Releases: `docs/release/README.md`.
Datenschutz: `PRIVACY.md`. Sicherheitslücken melden: `SECURITY.md`.

Siehe `docs/architecture/overview.md`, `docs/decisions/` und `docs/parity/`.
