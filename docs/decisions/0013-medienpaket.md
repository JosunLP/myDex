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
- **Gen 6–9** (Nachtrag): X/Y und Omega Rubin/Alpha Saphir als statische Sprites mit Shiny.
  Ab Gen 7 hat die Quelle nur animierte 3D-Modelle (0,1–6 MB je Bild, zusammen rund 10 GB)
  oder Box-Symbole. Gespeichert wird je Form und Spiel ein Einzelbild ohne Shiny: das erste
  Bild der Animation (Ultrasonne/Ultramond, gilt auch für Sonne/Mond) bzw. das Box-Symbol
  (Let's Go, Schwert/Schild, Strahlender Diamant/Leuchtende Perle, Legenden: Arceus,
  Karmesin/Purpur, Legends: Z-A, Champions). Transparenter Rand abgeschnitten, auf höchstens
  96 px verkleinert, Paletten-PNG; versioniert als `s96-v1`. Im Cache bleibt nur das Ergebnis.
  Erweiterungen nutzen die Bilder ihres Hauptspiels. Medienpaket damit rund 51 MB.
- **Paket:** eigene SQLite-Datei mit eigenem Schema (`media`), gzip-komprimiert in der App
  ausgeliefert (~7 MB) und über denselben Installer wie der Katalog installiert (Prüfsumme,
  Integrität, atomarer Wechsel), aber in einem eigenen Verzeichnis.
- **Unabhängig vom Katalog:** Fehlt oder scheitert das Medienpaket, läuft die App ohne Bilder
  weiter; Bilder sind nie Voraussetzung für Daten.
- **Anzeige:** Im gewählten Spiel dessen Sprite, sonst das Standard-Sprite. Pixelgrafik ohne
  Glättung. Bilder neben einem Namen sind für Screenreader ausgeblendet; in der Galerie tragen
  sie eine Beschreibung (Name, Spiel, Shiny).
- **Offizielles Artwork** (Nachtrag): je Form im Satz `artwork`, auf 256 px verkleinert und als
  PNG mit 256-Farben-Palette gespeichert. 224 Einträge für deckende Farben (Octree), 31 für
  halbtransparente Kanten (Durchschnittsfarbe je Deckkraftstufe), einer voll transparent. So
  bleiben Transparenz und weiche Kanten erhalten; etwa 17 KB statt 120 KB je Bild, zusammen
  rund 20 MB. Das Verfahren ist deterministisch und versioniert (`a256-v1`), das Ergebnis wird
  im Cache neben dem Original abgelegt.
- **Artwork-Farbe** (Schema 2): Die Pipeline leitet je Form die Hauptfarbe des Artworks ab
  (Tabelle `artwork_color`); sie färbt den Hintergrund der Pokédex-Anzeige. Gezählt werden
  deckende Pixel ohne Konturen und Glanzlichter, einsortiert in Farbwürfel und nach
  Farbintensität gewichtet; Ergebnis ist der Durchschnitt des schwersten Würfels. Versioniert als
  `c1`, deterministisch. Ohne Medienpaket gilt die Farbe des ersten Typs.
- **Nicht enthalten:** Shiny-Artwork und HOME-Renderings.

## Konsequenzen
- Das App-Paket wächst um etwa 27 MB, installiert um etwa 34 MB.
- Der erste Medienbau lädt rund 11 000 Dateien; danach liegen sie im Cache (`.dart_tool/sprites`,
  in der CI über `actions/cache`).
