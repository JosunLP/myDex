# 0007 – Katalog als SQLite-Paket über `sqlite3`, ohne Drift

Status: angenommen · ergänzt ADR 0003

## Kontext
ADR 0003 sah Drift für beide Datenbanken vor. Der Katalog wird aber ausschließlich von der
Pipeline geschrieben und von der App nur gelesen; er braucht weder Migrationen noch
reaktive Abfragen oder Codegenerierung.

## Entscheidung
- Der Katalog ist eine SQLite-Datei (Schema in `packages/catalog_store/lib/src/schema.dart`),
  die die Pipeline erzeugt und die App mit dem Paket `sqlite3` nur lesend öffnet
  (`immutable=1`, keine Journal-/Sperrdateien).
- `sqlite3` bringt über Build-Hooks auf allen Zielplattformen eine eigene SQLite-Version mit
  FTS5 mit; es ist keine System-SQLite und kein `sqlite3_flutter_libs` nötig.
- Kerndaten (Arten, Formen, Profile, Namen) werden beim Start in einem Hintergrund-Isolate in den
  Speicher geladen (`CatalogSnapshot`); große Tabellen (Erlernbarkeit, Attackenwerte, Suche)
  werden bei Bedarf abgefragt (`CatalogDetails`).
- Drift bleibt die Option für Nutzerdaten, sobald dort Migrationen oder Sync es erfordern.

## Konsequenzen
- Eine Abhängigkeit weniger und keine Codegenerierung im Build.
- Die Pipeline und die App teilen sich dasselbe Schema als Dart-Konstante.
- Schemaänderungen erhöhen `catalogSchemaVersion`; alte Pakete werden abgelehnt.
