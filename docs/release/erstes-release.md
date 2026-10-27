# Erstes Release (1.0.0) – Schritt für Schritt

Alles, was ohne Schlüssel und Gerät geht, ist erledigt: Version 1.0.0 steht in
`apps/pokedex/pubspec.yaml` und `CHANGELOG.md`, der Release-Workflow ist fertig. Es fehlen nur
die Schritte, die geheime Schlüssel oder ein Testgerät brauchen.

## 1. Android-Signaturschlüssel (Pflicht, einmalig)

```sh
keytool -genkeypair -v -keystore mydex-release.jks -alias mydex \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 mydex-release.jks > mydex-release.jks.b64   # macOS: base64 -i mydex-release.jks
```

`mydex-release.jks` und die Passwörter zusätzlich offline sichern: Ohne diesen Schlüssel lassen
sich installierte Apps nie mehr aktualisieren.

## 2. Katalog-Schlüssel (empfohlen, einmalig)

Damit die Ausgabe „sync“ und die Desktop-Apps neue Katalogstände über den eigenen Sync-Server
bekommen (ADR 0015):

```sh
dart run tools/data_pipeline/bin/data_pipeline.dart keygen --out catalog-signing.key
```

Die Ausgabe nennt den öffentlichen Schlüssel. `catalog-signing.key` ebenfalls sicher aufbewahren.

## 3. Secrets hinterlegen

GitHub → Repository → Settings → Secrets and variables → Actions → „New repository secret“:

| Secret | Inhalt |
|---|---|
| `MYDEX_KEYSTORE_BASE64` | Inhalt von `mydex-release.jks.b64` |
| `MYDEX_KEYSTORE_PASSWORD` | Passwort des Keystores |
| `MYDEX_KEY_ALIAS` | `mydex` |
| `MYDEX_KEY_PASSWORD` | Passwort des Schlüssels (bei keytool meist dasselbe) |
| `MYDEX_CATALOG_SIGNING_KEY` | Inhalt von `catalog-signing.key` (optional) |
| `MYDEX_CATALOG_PUBLIC_KEY` | öffentlicher Schlüssel aus Schritt 2 (optional) |

## 4. Tag setzen

Auf dem aktuellen `main`:

```sh
git checkout main && git pull
git tag v1.0.0 && git push origin v1.0.0
```

Der Workflow „Release“ baut alle Pakete und legt einen **Release-Entwurf** an (Inhalt siehe
`README.md` in diesem Ordner).

## 5. Abnahme und Veröffentlichung

1. `mydex-1.0.0-android.apk` aus dem Entwurf auf das GrapheneOS-Gerät laden und nach
   `grapheneos-abnahme.md` prüfen.
2. Optional: Sync-Server mit `mydex-sync-server-…` aufsetzen, `mydex-catalog-update-1.0.0.tar.gz`
   nach `/var/lib/mydex/catalog` entpacken und mit `--catalog-dir` starten.
3. Entwurf auf GitHub veröffentlichen. Für spätere Updates per Obtainium das Repository als
   Quelle eintragen (privates Repository: Obtainium braucht dafür ein GitHub-Token).

## Nicht enthalten

iOS-, macOS- und Windows-Signatur brauchen Entwicklerkonten bei Apple bzw. ein
Code-Signing-Zertifikat; bis dahin sind diese Pakete unsigniert (siehe `README.md`).
