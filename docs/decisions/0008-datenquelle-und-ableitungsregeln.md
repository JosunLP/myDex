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
1. Erlernbarkeits- oder Begegnungsdaten für die Form in der Spielgruppe → **bestätigt verfügbar**.
2. Art oder Form erst später eingeführt → **bestätigt nicht verfügbar**.
3. Sonst → **noch nicht recherchiert** (Datenlücke). Fehlende Daten werden nie als
   „nicht im Spiel“ dargestellt.

## Fundorte
- Begegnungen werden je Form, Version, Gebiet, Methode und Bedingungen zusammengefasst:
  niedrigstes/höchstes Level, Summe der Slot-Wahrscheinlichkeiten (höchstens 100 %).
- Versionsexklusive Pokémon ergeben sich direkt aus den Versionsdaten (z. B. Rettan nur in Rot).
- Hat eine Version **keine** Begegnungsdaten, zeigt die App „keine Fundortdaten“ – nie
  „nicht fangbar“. Fehlt nur eine einzelne Form, heißt es „in den Fundortdaten nicht enthalten“.

## Zucht
- Regelwerke mit Zucht: Gen 2–9, ohne Let's Go, Legends: Arceus, Colosseum/XD,
  Legends: Z-A/Mega Dimension und Champions.
- Eine Art gilt als schlüpfbar, wenn ein Mitglied ihrer Entwicklungsfamilie Eier legen kann
  (nicht nur „unbekannt“/Ditto). Die App nennt Zucht nur für Standardformen mit bestätigter
  Verfügbarkeit; das Ei schlüpft als Grundform der Familie. Rauch-/Inzens-Sonderfälle
  (z. B. Azurill) sind nicht modelliert – die App macht dazu keine Aussage.

## Tausch zwischen Spielen
- Tauschgruppen nach Spielgeneration bzw. Spielfamilie (Gen 1–7, Let's Go, Schwert/Schild mit
  DLC, Strahlender Diamant/Leuchtende Perle, Karmesin/Purpur mit DLC); Gen 1 und 2 tauschen
  über die Zeitkapsel. Japanische Erstausgaben bilden eine eigene Gruppe. Legenden: Arceus,
  Legends: Z-A, Mega Dimension und Champions haben keine Tauschpartner. Übertragungen über
  Pokémon HOME, Poké-Transfer und Ähnliches sind nicht berücksichtigt.
- Die App nennt „Durch Tausch aus …“, wenn eine Form im gewählten Spiel existiert, dort aber
  keine Fundorte hat und in einem Partnerspiel laut Fundortdaten vorkommt.

## Events
- Mysteriöse Pokémon (`is_mythical` der Quelle) werden als Event-Pokémon gekennzeichnet,
  sofern sie im gewählten Spiel existieren. Konkrete Verteilungen (Zeitraum, Region, Code)
  enthält die Quelle nicht; die App nennt sie daher nicht.

## Entwicklungen
- Gültig ab der in der Quelle genannten Spielgruppe und ab der Generation beider Arten.
- Ortsgebundene Entwicklungen nur in Spielgruppen, deren Regionen den Ort enthalten.
- Regionale Entwicklungen (z. B. Pikachu → Alola-Raichu in Alola) ersetzen in ihrer Region die
  allgemeine Entwicklung.
- Kanten zu oder von bestätigt nicht verfügbaren Formen werden ausgeblendet.

## Bekannte Lücken (im Datenstand sichtbar)
- Pokédex- und Effekttexte sind noch nicht importiert.
- Die Quelle hat keine Begegnungsdaten u. a. für Strahlender Diamant/Leuchtende Perle,
  Legends: Arceus, Karmesin/Purpur (inkl. DLC), Legends: Z-A, Mega Dimension und Champions.
- Konkrete Event-Verteilungen (Zeiträume, Codes) und Übertragungen zwischen Generationen sind
  nicht enthalten.
- Viele Methoden- und Bedingungsnamen gibt es in der Quelle nur auf Englisch; die App zeigt
  dann den englischen Namen.
- Fluch hatte in Gen 2–4 den Typ „???“, der nicht modelliert ist; dort fehlen seine Werte.
- Schatten-Attacken (Colosseum/XD) sind ausgelassen.
- Regelwerke von Legends: Z-A, Mega Dimension und Champions sind noch nicht geprüft und
  folgen vorerst den modernen Regeln. Statusformeln von Let's Go (AVs) und Legends: Arceus
  (Effort Levels) sind nicht abgebildet.
- Die Quelle enthält einen doppelten Item-Bezeichner; die zweite Fassung erhält `--<Quell-ID>`.
