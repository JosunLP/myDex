# Architekturüberblick

Kurzfassung des Gesamtentwurfs. Verbindliche Einzelentscheidungen stehen in `docs/decisions/`.

## Produktvision

Eine schnelle, datenschutzfreundliche Pokémon-Enzyklopädie für Smartphone und Desktop, ohne
Konto nutzbar, mit vollständig offline verfügbaren Kernfunktionen. Funktionsumfang mindestens auf
dem Niveau der in `docs/parity/` eingefrorenen Referenzversion.

Zielplattformen: Android, GrapheneOS ohne Play Services (Testziel, kein eigener Port), iOS,
Windows, macOS, Linux.

## Leitentscheidungen

1. Flutter/Dart für eine gemeinsame Client-Codebase (ADR 0001).
2. Lokaler modularer Monolith; kein Backend fürs Nachschlagen (ADR 0002).
3. Öffentlicher Katalog und persönliche Daten in getrennten Speichern (ADR 0003).
4. Spielkontext wird explizit durch jede regelabhängige Abfrage gereicht (ADR 0004).
5. Fehlende Daten sind nie „nicht verfügbar“ – fünf unterscheidbare Zustände (ADR 0005).
6. Entwicklungsbedingungen sind deklarative Daten, nie Skripte (ADR 0006).
7. Katalog als nur lesbares SQLite-Paket über `sqlite3` (ADR 0007).
8. Festgehaltene Datenquelle und dokumentierte Ableitungsregeln (ADR 0008).
9. Team-Prüfung mit vier Zuständen, ohne Legalitätsgarantie (ADR 0009).
10. Datensicherung als versionierte, optional verschlüsselte Datei (ADR 0010).
11. Vorlesen über die System-Sprachausgabe, fünf Oberflächensprachen (ADR 0011).
12. Optionaler Sync über einen selbst gehosteten Server (ADR 0012).
13. Sprites als eigenes, mitgeliefertes Medienpaket (ADR 0013).

## Schichten

| Schicht | Paket | Inhalt |
|---|---|---|
| Presentation | `apps/pokedex` | Widgets, Navigation, Darstellungszustände |
| Application | `packages/application` | Anwendungsfälle, Repository-Schnittstellen, Suche |
| Domain | `packages/domain`, `packages/game_rules` | Modelle, Regelwerke, Berechnungen |
| Infrastructure | `packages/catalog_store`, `packages/user_store`, `packages/sync` | Katalogpaket, Nutzerdaten, Abgleich |

Regel: innere Schichten kennen keine äußeren. Infrastruktur implementiert Schnittstellen aus
`application`.

## Datenmodell (Kern)

- `Species` – Art mit nationaler Nummer.
- `Variety` / `Form` – spielmechanisch relevante Erscheinungsform; eigene stabile ID.
  Nationaldex-Nummern sind keine Primärschlüssel für Formen.
- `GameVersion`, `VersionGroup`, `Ruleset` – Spiel, Spielgruppe, mechanische Regeln.
- `FormGameProfile` – Typen, Basiswerte, Fähigkeiten und Verfügbarkeit einer Form in einer
  Spielgruppe. Beispiel: Piepi ist bis Gen 5 Normal, ab Gen 6 Fee.
- `EvolutionEdge` mit strukturierter `EvolutionCondition` (UND/ODER, Level, Item, …).
- Nutzerdaten: `CollectionEntry` je Umfang (Spiel oder global), Form und Shiny-Flag.
  Shiny ist eine Eigenschaft, keine Form.

## Offline und Updates

Der Kernkatalog wird mit der App ausgeliefert, damit der erste Start ohne Netz funktioniert.
Updates: signiertes Manifest → temporärer Download → Hash-/Integritätsprüfung → atomare
Aktivierung → letzte Version für Rollback behalten. App-Version, Katalogversion und
Nutzerdatenschema sind drei getrennte Versionen.

Aktueller Stand: Das Katalogpaket (gzip-komprimierte SQLite-Datei + Manifest mit SHA-256) wird
mit der App ausgeliefert und beim ersten Start bzw. nach App-Updates von `CatalogInstaller`
installiert. Netz-Updates mit signiertem Manifest nutzen später denselben Installer.

## Datenpipeline

`tools/data_pipeline` lädt die benötigten PokéAPI-CSV-Tabellen eines festgehaltenen Commits,
prüft sie gegen `data/source_manifests/pokeapi.json`, leitet Spielprofile ab (ADR 0008), baut
den Katalog, validiert ihn über denselben Leser wie die App und verpackt ihn deterministisch.
Abdeckung je Spiel wird mitgeliefert und in der App unter „Datenstand und Abdeckung“ gezeigt.

## Suche

Sprachübergreifend über Namen, Aliase und Nummern. Ranking: exakte Nummer/exakter Name →
exakter Alias → Präfix → Teilstring → kontrollierte Tippfehlertoleranz. Normalisierung entfernt
Diakritika und vereinheitlicht ß, ♀/♂ und Satzzeichen.

## Team-Analyse

Drei getrennte Stufen: Basistypen-Analyse (implementiert), kontextabhängige Analyse
(Fähigkeiten, Items, Wetter) und Legalitätsprüfung. Ergebnisse der Legalitätsprüfung sind
`gültig`, `ungültig`, `teilweise geprüft` oder `Datenlage unzureichend` – nie eine
ungedeckte Garantie.

## Sync (optional)

Selbst gehosteter Server (`tools/sync_server`) und Client-Logik in `packages/sync` (ADR 0012).
Outbox je Gerät, kontoweite Revisionen mit optimistischer Nebenläufigkeit, Grabsteine für
Löschungen, Konfliktkopien statt stillem Überschreiben. HTTPS über einen Reverse-Proxy; keine
Ende-zu-Ende-Verschlüsselung in Version 1. Die Android-Standardausgabe enthält keinen Sync und
keine Internet-Berechtigung.

## GrapheneOS

Abnahmekriterium: Betrieb ohne Google Play Services. Kein Google-Login-, Play-Integrity- oder
Push-Zwang; signierte APK zusätzlich zum Store; keine unnötigen Berechtigungen.

## Phasen

| Phase | Inhalt |
|---|---|
| 0 | Referenzanalyse, Paritätsmatrix, Rechteinventar, Plattform-Spikes |
| 1 | Fundament, vertikaler Durchstich (abgeschlossen) |
| 2 | Vollständiger Wissenskatalog: 2a Pipeline, Attacken, Fähigkeiten, Historie (abgeschlossen); 2b Fundorte und Beschaffung (abgeschlossen) |
| 3 | Sammlung und Teams: 3a Teams, 3b Sammlung, Filter, Export/Import (abgeschlossen) |
| 4 | Referenzparität: 4a Sprachen, Hilfe, Vorlesen (abgeschlossen); 4b Sync (abgeschlossen); Galerie (Sprites, abgeschlossen) |
| 5 | Stabilisierung und Veröffentlichung: Barrierefreiheit, Signatur, Release-Workflow, Abnahme (laufend) |
