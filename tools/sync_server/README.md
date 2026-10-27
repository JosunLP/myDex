# myDex sync server

Optional, self-hosted server for syncing personal data (collection, teams, filter presets)
between devices. One process, one SQLite file, no other services. Decisions and limits:
`docs/decisions/0012-sync.md`.

## Operation

```sh
# Create an account – the access token is printed only this once
dart run tools/sync_server/bin/sync_server.dart create-account --db /var/lib/mydex/sync.sqlite --name my-account

# Start the server (listens locally only)
dart run tools/sync_server/bin/sync_server.dart serve --db /var/lib/mydex/sync.sqlite --port 8787
```

More commands: `list-accounts`, `rotate-token --name …` (new token, old one invalid),
`delete-account --name …` (account including its data).

Catalog updates (optional, ADR 0015): with `serve … --catalog-dir /var/lib/mydex/catalog` the
server serves a signed update (`update.json` + `catalog.sqlite.gz`, from
`mydex-catalog-update-…tar.gz` or `data_pipeline sign-update`) to authenticated devices. The apps
verify the signature themselves; the server cannot install anything unsigned.

For permanent operation every release ships ready-made packages
(`mydex-sync-server-…-linux-x64.tar.gz`, program under `bin/`, SQLite under `lib/`). To build it
yourself:

```sh
dart build cli --target tools/sync_server/bin/sync_server.dart -o build/sync_server
build/sync_server/bundle/bin/sync_server serve --db /var/lib/mydex/sync.sqlite
```

Example systemd unit (`/etc/systemd/system/mydex-sync.service`):

```ini
[Unit]
Description=myDex sync server
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

The server only speaks HTTP and binds to `127.0.0.1` by default. Outside your own device the app
connects exclusively via HTTPS, so put a reverse proxy with a certificate in front of it, e.g.
Caddy:

```text
sync.example.org {
    reverse_proxy 127.0.0.1:8787
}
```

In the app, enter the address (`https://sync.example.org`) and the access token under
*More → Sync*. On Android this needs the `sync` flavor.

## API

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/v1/health` | Reachability, protocol version |
| `POST` | `/v1/sync` | Send changes, fetch other devices' changes (`Authorization: Bearer …`) |
| `DELETE` | `/v1/account` | Delete all data of the account |
| `GET` | `/v1/catalog/update` | Signed catalog update description (with `--catalog-dir`) |
| `GET` | `/v1/catalog/pack` | The catalog pack (with `--catalog-dir`) |

Per account the server stores records (kind, ID, revision, JSON, timestamp) and tombstones for
deletions. Access tokens are stored only as SHA-256 hashes. The app encrypts all records
end-to-end beforehand (ADR 0014): the server only stores opaque IDs and ciphertexts and cannot
read the content.
