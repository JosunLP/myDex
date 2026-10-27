# 0015 – Katalog-Updates über den eigenen Sync-Server

Status: angenommen (ergänzt ADR 0007 und ADR 0012)

## Kontext
Bisher kam ein neuer Katalog nur mit einer neuen App-Version. Das Repository ist privat, eine
öffentliche Download-Quelle gibt es nicht. Die Ausgabe „sync“ und die Desktop-Ausgaben sprechen
aber ohnehin mit einem selbst betriebenen Server. Die Standardausgabe für Android bleibt ohne
Internet-Berechtigung.

## Entscheidung
- **Quelle:** der eigene Sync-Server. Mit `serve --catalog-dir <dir>` liefert er
  `GET /v1/catalog/update` (signierte Beschreibung) und `GET /v1/catalog/pack` (gzip-Paket),
  beide nur mit gültigem Zugangsschlüssel. Ohne Verzeichnis antwortet er mit 404.
- **Signatur:** Ed25519 über die kanonische JSON-Form des Paket-Manifests (Schlüssel sortiert,
  ohne Leerzeichen). Das Manifest enthält Revision, Schemaversion, SHA-256, Größe und eine
  **Reihenfolgenummer** (`sequence` = Commit-Zeit der Datenquelle · 100 + Schemaversion).
- **Vertrauen:** Der öffentliche Schlüssel wird beim Bauen eingesetzt
  (`--dart-define=MYDEX_CATALOG_KEY=<base64>[,<base64>]`, mehrere für einen Schlüsselwechsel).
  Ohne Schlüssel ist die Funktion abgeschaltet; der Server allein kann nichts einspielen.
- **Annahme nur, wenn** die Signatur passt, die Schemaversion zur App passt und die
  Reihenfolgenummer größer ist als die installierte (kein Zurückspielen alter Stände).
  Danach gelten die Prüfungen aus ADR 0007: Prüfsumme, Größe, Integritätstest, Revision im
  Paket, atomarer Wechsel, Rückfall auf die Vorversion.
- **Start:** Der installierte Katalog wird genommen, wenn er dieselbe Revision wie der
  mitgelieferte hat oder eine höhere Reihenfolgenummer. Ein App-Update mit neuerem Katalog
  ersetzt also ein älteres Netz-Update.
- **Auslösen:** von Hand unter „Datenstand und Abdeckung“ („Prüfen“), nur in Ausgaben mit
  Netzwerk und nur bei verbundenem Sync.
- **Werkzeuge:** `data_pipeline keygen --out <datei>` erzeugt das Schlüsselpaar,
  `data_pipeline sign-update --key <datei> --out <dir>` legt `update.json` und das Paket ab.
  Der Release-Workflow tut das, wenn das Secret `MYDEX_CATALOG_SIGNING_KEY` gesetzt ist.

## Konsequenzen
- Neue Daten (z. B. ein neues Spiel im selben Schema) brauchen kein App-Update mehr.
- Ändert sich das Schema, ist weiterhin ein App-Update nötig; die App meldet das.
- Der private Signaturschlüssel ist die Vertrauensbasis: getrennt vom Server aufbewahren.
  Geht er verloren, kommt ein neuer Schlüssel mit der nächsten App-Version.
- Die Ausgabe „offline“ bekommt Katalog-Updates weiterhin nur über App-Updates.
