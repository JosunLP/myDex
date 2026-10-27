# 0013 – Medienpaket (Sprites)

Status: angenommen

## Kontext
Die Bildrechte sind für die private Nutzung geklärt (Rechteinventar). Bilder sollen offline
verfügbar sein, auch in der Android-Ausgabe ohne Internet-Berechtigung, und den Spielkontext
(ADR 0004) widerspiegeln.

## Entscheidung
- **Quelle:** `PokeAPI/sprites`, festgehalten auf einen Commit. Dateien unter einem Commit sind
  unveränderlich; die CI baut das Paket neu und vergleicht es mit dem eingecheckten.
- **Umfang:** Standard- und Shiny-Sprite jeder Form sowie die Sprites der Spiele aus Gen 1–5
  (Gen 1–2 in transparenter Fassung, Gen 1 ohne Shiny). Kandidaten sind die Formen, die im
  jeweiligen Spiel nicht bestätigt fehlen – abgeleitet aus dem gebauten Katalog.
- **Paket:** eigene SQLite-Datei mit eigenem Schema (`media`), gzip-komprimiert in der App
  ausgeliefert (~7 MB) und über denselben Installer wie der Katalog installiert (Prüfsumme,
  Integrität, atomarer Wechsel), aber in einem eigenen Verzeichnis.
- **Unabhängig vom Katalog:** Fehlt oder scheitert das Medienpaket, läuft die App ohne Bilder
  weiter; Bilder sind nie Voraussetzung für Daten.
- **Anzeige:** Im gewählten Spiel dessen Sprite, sonst das Standard-Sprite. Pixelgrafik ohne
  Glättung. Bilder neben einem Namen sind für Screenreader ausgeblendet; in der Galerie tragen
  sie eine Beschreibung (Name, Spiel, Shiny).
- **Nicht enthalten:** offizielles Artwork und HOME-Renderings (~120 KB je Bild, zusammen weit
  über 100 MB). Ein optionales, nachladbares Artwork-Paket kann dasselbe Format nutzen.

## Konsequenzen
- Das App-Paket wächst um etwa 7 MB, installiert um etwa 12 MB.
- Der erste Medienbau lädt rund 11 000 Dateien; danach liegen sie im Cache (`.dart_tool/sprites`,
  in der CI über `actions/cache`).
