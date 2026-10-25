# 0008 – Datenquelle und Ableitungsregeln

Status: angenommen

## Quelle
PokéAPI-CSV-Daten in einem festgehaltenen Commit (`tools/data_pipeline/lib/src/source.dart`).
Jede Tabelle ist mit SHA-256 in `data/source_manifests/pokeapi.json` erfasst; ein abweichender
Download bricht den Build ab. Die Pipeline ist deterministisch: gleicher Quellstand → byte-
identisches Paket.

## Regeln (spielmechanische Fakten, keine Schätzungen)
- **Historische Werte:** „*_past“-Tabellen gelten bis einschließlich ihrer Generation; es gilt der
  früheste passende Eintrag, sonst der aktuelle Wert (Typen, Basiswerte, Fähigkeiten).
- **Gen 1:** gemeinsamer Spezial-Wert, keine Fähigkeiten. **Versteckte Fähigkeiten** erst ab Gen 5.
- **Attacken:** `move_changelog` enthält die Werte *vor* einer Spielgruppe; je Feld gilt der
  früheste Eintrag nach der betrachteten Spielgruppe. Bis Gen 3 bestimmt der Typ die
  Schadensklasse.
- **Regelwerke:** Let's Go und Legends: Arceus ohne Fähigkeiten und getragene Items.

## Verfügbarkeit einer Form in einer Spielgruppe (ADR 0005)
1. Erlernbarkeitsdaten für die Form in der Spielgruppe → **bestätigt verfügbar**.
2. Art oder Form erst später eingeführt → **bestätigt nicht verfügbar**.
3. Sonst → **noch nicht recherchiert** (Datenlücke). Fehlende Daten werden nie als
   „nicht im Spiel“ dargestellt.

## Entwicklungen
- Gültig ab der in der Quelle genannten Spielgruppe und ab der Generation beider Arten.
- Ortsgebundene Entwicklungen nur in Spielgruppen, deren Regionen den Ort enthalten.
- Regionale Entwicklungen (z. B. Pikachu → Alola-Raichu in Alola) ersetzen in ihrer Region die
  allgemeine Entwicklung.
- Kanten zu oder von bestätigt nicht verfügbaren Formen werden ausgeblendet.

## Bekannte Lücken (im Datenstand sichtbar)
- Fundorte, Pokédex- und Effekttexte sind noch nicht importiert.
- Fluch hatte in Gen 2–4 den Typ „???“, der nicht modelliert ist; dort fehlen seine Werte.
- Schatten-Attacken (Colosseum/XD) sind ausgelassen.
- Regelwerke von Legends: Z-A, Mega Dimension und Champions sind noch nicht geprüft und
  folgen vorerst den modernen Regeln. Statusformeln von Let's Go (AVs) und Legends: Arceus
  (Effort Levels) sind nicht abgebildet.
- Die Quelle enthält einen doppelten Item-Bezeichner; die zweite Fassung erhält `--<Quell-ID>`.
