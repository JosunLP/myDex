# Release

## Ablauf
1. `main` ist grün (CI inkl. Berechtigungsprüfung der APKs und Barrierefreiheitstests).
2. In `CHANGELOG.md` „Unveröffentlicht“ in `## [X.Y.Z] – JJJJ-MM-TT` umbenennen und mergen.
3. Tag setzen: `git tag vX.Y.Z && git push origin vX.Y.Z`.
4. Der Workflow „Release“ baut und legt eine **Release als Entwurf** an:
   - `mydex-X.Y.Z-android.apk` (Ausgabe „offline“, keine Berechtigungen)
   - `mydex-sync-X.Y.Z-android.apk` (Ausgabe „sync“, nur Internet)
   - `mydex-X.Y.Z-linux-x64.tar.gz`, `mydex-X.Y.Z-windows-x64.zip`, `mydex-X.Y.Z-macos.zip`
   - `mydex-sync-server-X.Y.Z-linux-x64.tar.gz`
   - `mydex-catalog-update-X.Y.Z.tar.gz` (nur mit Signaturschlüssel, siehe unten)
   - `SHA256SUMS`, `android-certificates.txt`
5. Abnahme nach `grapheneos-abnahme.md` mit der Entwurfs-APK.
6. Release-Entwurf auf GitHub veröffentlichen.

Versionsnummern: `X.Y.Z` aus dem Tag; Android-`versionCode` = `X·100000 + Y·1000 + Z`.

## Android-Signatur (einmalig)
Der Schlüssel identifiziert die App dauerhaft – ohne ihn sind keine Updates möglich. Sicher
und zusätzlich offline aufbewahren.

```sh
keytool -genkeypair -v -keystore mydex-release.jks -alias mydex \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 mydex-release.jks   # Ausgabe als Secret hinterlegen
```

GitHub → Settings → Secrets and variables → Actions:

| Secret | Inhalt |
|---|---|
| `MYDEX_KEYSTORE_BASE64` | Keystore, Base64-kodiert |
| `MYDEX_KEYSTORE_PASSWORD` | Passwort des Keystores |
| `MYDEX_KEY_ALIAS` | Alias, z. B. `mydex` |
| `MYDEX_KEY_PASSWORD` | Passwort des Schlüssels |

Lokal geht stattdessen `apps/pokedex/android/key.properties` (nie einchecken):

```properties
storeFile=/absoluter/pfad/mydex-release.jks
storePassword=…
keyAlias=mydex
keyPassword=…
```

Ohne Schlüssel bauen lokale Release-Builds mit dem Debug-Schlüssel; der Release-Workflow
bricht dann ab (`MYDEX_REQUIRE_SIGNING=true`) und prüft zusätzlich, dass kein
Debug-Zertifikat im Paket steckt.

## Katalog-Updates (optional, ADR 0015)
Damit die Ausgaben mit Netzwerk neue Katalogstände über den eigenen Sync-Server bekommen,
einmalig ein Schlüsselpaar erzeugen:

```sh
dart run tools/data_pipeline/bin/data_pipeline.dart keygen --out catalog-signing.key
```

| Secret | Inhalt |
|---|---|
| `MYDEX_CATALOG_SIGNING_KEY` | Inhalt von `catalog-signing.key` (privat) |
| `MYDEX_CATALOG_PUBLIC_KEY` | ausgegebener öffentlicher Schlüssel |

Der Release-Workflow baut den öffentlichen Schlüssel in die Apps ein und legt
`mydex-catalog-update-X.Y.Z.tar.gz` bei. Auf dem Server entpacken und mit
`serve --catalog-dir <dir>` ausliefern. Ein neuer Katalog ohne App-Release:

```sh
dart run tools/data_pipeline/bin/data_pipeline.dart sign-update \
  --key catalog-signing.key --out /var/lib/mydex/catalog
```

## Nicht automatisiert
- **iOS:** braucht ein Apple-Entwicklerkonto (Signatur, TestFlight/App Store).
- **macOS:** das Paket ist nicht signiert/notarisiert; Gatekeeper fragt beim ersten Start.
- **Windows:** nicht signiert; SmartScreen kann warnen.
- **Verteilung:** myDex ist eine private App. Releases sind GitHub-Releases (APK direkt
  installieren, z. B. per Obtainium); keine Store- oder F-Droid-Veröffentlichung.
