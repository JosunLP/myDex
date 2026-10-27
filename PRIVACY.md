# Datenschutz

*English summary below.*

myDex ist ein inoffizielles Fanprojekt und funktioniert ohne Konto und ohne Internet.

## Welche Daten verarbeitet die App?
- **Katalog** (Pokémon, Attacken, Orte …): wird mit der App ausgeliefert und lokal gelesen.
- **Deine Daten** (Sammlung, Teams, Filtervorlagen, Einstellungen): werden ausschließlich auf
  deinem Gerät gespeichert, im privaten Verzeichnis der App.
- **Keine** Analyse, Absturzberichte, Werbung, Tracker oder Gerätekennungen. Die App sendet
  von sich aus nichts.

## Wann verlassen Daten das Gerät?
Nur, wenn du es selbst auslöst:
- **Datensicherung:** Du wählst Speicherort und optional ein Passwort (AES-256-GCM).
- **Synchronisierung (optional):** Sammlung, Teams und Filtervorlagen gehen per HTTPS an einen
  Server, dessen Adresse du einträgst – in der Regel deinen eigenen. Auf dem Server liegen die
  Daten nicht Ende-zu-Ende-verschlüsselt; wer ihn betreibt, kann sie lesen. Über „Meine Daten
  auf dem Server löschen“ entfernst du sie dort. Unter Android gibt es den Abgleich nur in der
  Ausgabe „myDex Sync“; die Standardausgabe hat keine Internet-Berechtigung.
- **Vorlesen:** Nutzt die Sprachausgabe deines Geräts. Ob diese Text an Dritte sendet, hängt
  von der installierten Engine ab (RHVoice und eSpeak NG arbeiten lokal).

## Berechtigungen
- Android „myDex“: keine. Android „myDex Sync“: nur Internet.
- macOS: Netzwerkzugriff (nur für den optionalen Abgleich), vom Nutzer gewählte Dateien.

## Löschen
App deinstallieren oder die App-Daten löschen entfernt alles auf dem Gerät.

---

## English summary
myDex works without an account and without internet. Your collection, teams, presets and
settings are stored only on your device. There is no analytics, crash reporting, advertising
or tracking. Data leaves the device only when you export a backup or turn on the optional sync
with a server you choose (HTTPS, not end-to-end encrypted on the server). The standard Android
edition requests no permissions at all; "myDex Sync" requests internet access only.
