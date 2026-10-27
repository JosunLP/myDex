# Änderungen

Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionen nach
[Semantic Versioning](https://semver.org/lang/de/). Vor einem Release wird „Unveröffentlicht“
in die neue Version umbenannt; der Release-Workflow übernimmt diesen Abschnitt.

## [Unveröffentlicht]

### Neu
- Pokémon-Dex mit allen Spielen: Formen, Typen, Basiswerte und Fähigkeiten je Spiel,
  Entwicklungen mit Bedingungen, Attacken mit Erlernbarkeit und Änderungshistorie.
- Fundorte je Spielversion, Beschaffung über Entwicklung, Zucht, Tausch zwischen Spielen und
  Events (Mysteriöse Pokémon); Datenlücken werden als
  solche gezeigt, nie als „nicht fangbar“.
- Sammlung je Spiel und spielübergreifend, mit Shiny und Fangdatum; kombinierbare Filter und
  Vorlagen.
- Teams mit Werteberechnung, Prüfung (gültig / teilweise / Datenlage unzureichend / ungültig),
  Typanalyse und Attackenvorschlägen.
- Datensicherung als Datei, optional mit Passwort verschlüsselt.
- Oberfläche auf Deutsch, Englisch, Französisch, Spanisch und Italienisch; Namen in elf Sprachen.
- Vorlesen über die Sprachausgabe des Systems; Offline-Hilfe.
- Optionaler Abgleich über einen selbst gehosteten Server, Ende-zu-Ende-verschlüsselt mit
  Sync-Passwort; Android-Ausgabe „sync“.
- Katalog-Updates über den eigenen Sync-Server, mit Ed25519 signiert und gegen den in der App
  hinterlegten Schlüssel geprüft; ältere Stände werden nicht eingespielt.
- Galerie mit offiziellem Artwork und Sprites je Spiel (Gen 1–5), Standard und Shiny;
  Vorschaubilder in Dex, Sammlung und Teams – vollständig offline.
- Gestaltung im Stil des Pokédex: rotes Gehäuse, Linse mit Signal-LEDs, Anzeige mit Artwork,
  Typfarbe und Digitalnummer; dunkle Variante.
- Barrierefreiheit automatisch geprüft (Tippflächen, Beschriftungen, Kontrast).

### Sicherheit und Datenschutz
- Keine Konten, keine Analyse, keine Werbung. Die Android-Standardausgabe hat keine
  Internet-Berechtigung (in der CI geprüft).
