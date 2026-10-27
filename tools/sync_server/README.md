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
`delete-account --name …` (Konto samt Daten). Für den Dauerbetrieb lässt sich der Server mit
`dart compile exe tools/sync_server/bin/sync_server.dart -o mydex-sync` als einzelne Datei bauen.

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
für Löschungen. Zugangsschlüssel liegen nur als SHA-256-Hash vor. Die Daten selbst sind auf
dem Server nicht Ende-zu-Ende-verschlüsselt; wer den Server betreibt, kann sie lesen.
