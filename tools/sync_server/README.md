# myDex-Sync-Server

Optionaler, selbst gehosteter Server für den Abgleich persönlicher Daten (Sammlung, Teams,
Filtervorlagen) zwischen Geräten. Ein Prozess, eine SQLite-Datei, keine weiteren Dienste.
Entscheidungen und Grenzen: `docs/decisions/0012-sync.md`.

## Betrieb

```sh
# Konto anlegen – der Zugangsschlüssel wird nur dieses eine Mal ausgegeben
dart run tools/sync_server/bin/sync_server.dart create-account --db /var/lib/mydex/sync.sqlite --name mein-konto

# Server starten (lauscht nur lokal)
dart run tools/sync_server/bin/sync_server.dart serve --db /var/lib/mydex/sync.sqlite --port 8787
```

Weitere Befehle: `list-accounts`, `rotate-token --name …` (neuer Schlüssel, alter ungültig),
`delete-account --name …` (Konto samt Daten).

Katalog-Updates (optional, ADR 0015): Mit `serve … --catalog-dir /var/lib/mydex/catalog` liefert
der Server ein signiertes Update (`update.json` + `catalog.sqlite.gz`, aus
`mydex-catalog-update-…tar.gz` oder `data_pipeline sign-update`) an angemeldete Geräte aus.
Die Apps prüfen die Signatur selbst; der Server kann nichts Unsigniertes einspielen.

Für den Dauerbetrieb gibt es fertige Pakete an jeder Release (`mydex-sync-server-…-linux-x64.tar.gz`,
Programm unter `bin/`, SQLite unter `lib/`). Selbst bauen:

```sh
dart build cli --target tools/sync_server/bin/sync_server.dart -o build/sync_server
build/sync_server/bundle/bin/sync_server serve --db /var/lib/mydex/sync.sqlite
```

Beispiel für systemd (`/etc/systemd/system/mydex-sync.service`):

```ini
[Unit]
Description=myDex-Sync-Server
After=network.target

[Service]
ExecStart=/opt/mydex-sync/bin/sync_server serve --db /var/lib/mydex/sync.sqlite --port 8787
DynamicUser=yes
StateDirectory=mydex
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## TLS

Der Server spricht nur HTTP und bindet standardmäßig an `127.0.0.1`. Die App verbindet sich
außerhalb des eigenen Geräts ausschließlich über HTTPS. Davor gehört deshalb ein Reverse-Proxy
mit Zertifikat, z. B. Caddy:

```text
sync.example.org {
    reverse_proxy 127.0.0.1:8787
}
```

In der App unter *Mehr → Synchronisierung* die Adresse (`https://sync.example.org`) und den
Zugangsschlüssel eintragen. Unter Android ist dafür die Ausgabe `sync` nötig.

## Schnittstelle

| Methode | Pfad | Zweck |
|---|---|---|
| `GET` | `/v1/health` | Erreichbarkeit, Protokollversion |
| `POST` | `/v1/sync` | Änderungen senden, fremde Änderungen abholen (`Authorization: Bearer …`) |
| `DELETE` | `/v1/account` | alle Daten des Kontos löschen |

Gespeichert werden je Konto Datensätze (Art, ID, Revision, JSON, Zeitstempel) und Grabsteine
für Löschungen. Zugangsschlüssel liegen nur als SHA-256-Hash vor. Die App verschlüsselt alle
Datensätze vorher Ende-zu-Ende (ADR 0014): Der Server speichert nur undurchsichtige IDs und
Chiffrate und kann den Inhalt nicht lesen.
