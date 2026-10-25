# 0003 – Katalog und Nutzerdaten getrennt speichern

Status: angenommen · Katalogteil konkretisiert durch ADR 0007

## Entscheidung
Der öffentliche Katalog ist nur lesbar und wird als Ganzes ersetzt. Persönliche Daten
(Sammlung, Teams, Filter, Einstellungen) liegen in einem eigenen Speicher. Verknüpfung über
stabile IDs; die Konsistenz prüft die Anwendung.

Katalog: SQLite-Paket, nur lesbar, installiert unter `catalog/` (ADR 0007).
Nutzerdaten: vorerst eine atomar geschriebene JSON-Datei hinter `CollectionRepository`;
Drift folgt, sobald Migrationen oder Sync es erfordern.

## Konsequenzen
Katalogupdates können persönliche Daten nie überschreiben. Verwaiste IDs nach einem Update
werden angezeigt, nicht gelöscht.
