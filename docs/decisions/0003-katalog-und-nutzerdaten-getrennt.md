# 0003 – Katalog und Nutzerdaten getrennt speichern

Status: angenommen

## Entscheidung
Der öffentliche Katalog ist nur lesbar und wird als Ganzes ersetzt. Persönliche Daten
(Sammlung, Teams, Filter, Einstellungen) liegen in einem eigenen Speicher. Verknüpfung über
stabile IDs; die Konsistenz prüft die Anwendung.

Zielzustand: zwei SQLite-Datenbanken via Drift. Im ersten Durchstich: gebündeltes
JSON-Katalogpaket und eine atomar geschriebene JSON-Datei für Nutzerdaten – jeweils hinter den
Schnittstellen `CatalogRepository` und `CollectionRepository`.

## Konsequenzen
Katalogupdates können persönliche Daten nie überschreiben. Verwaiste IDs nach einem Update
werden angezeigt, nicht gelöscht.
