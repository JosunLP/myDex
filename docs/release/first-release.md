# First release (1.0.0) – step by step

Everything that works without keys and a device is done: version 1.0.0 is set in
`apps/pokedex/pubspec.yaml` and `CHANGELOG.md`, and the release workflow is ready. Only the
steps that need secret keys or a test device remain.

## 1. Android signing key (required, once)

```sh
keytool -genkeypair -v -keystore mydex-release.jks -alias mydex \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 mydex-release.jks > mydex-release.jks.b64   # macOS: base64 -i mydex-release.jks
```

Back up `mydex-release.jks` and the passwords offline as well: without this key, installed apps
can never be updated again.

## 2. Catalog key (recommended, once)

So that the “sync” flavor and the desktop apps receive new catalog snapshots via your own sync
server (ADR 0015):

```sh
dart run tools/data_pipeline/bin/data_pipeline.dart keygen --out catalog-signing.key
```

The output shows the public key. Keep `catalog-signing.key` safe as well.

## 3. Add the secrets

GitHub → repository → Settings → Secrets and variables → Actions → “New repository secret”:

| Secret | Content |
|---|---|
| `MYDEX_KEYSTORE_BASE64` | Content of `mydex-release.jks.b64` |
| `MYDEX_KEYSTORE_PASSWORD` | Keystore password |
| `MYDEX_KEY_ALIAS` | `mydex` |
| `MYDEX_KEY_PASSWORD` | Key password (with keytool usually the same) |
| `MYDEX_CATALOG_SIGNING_KEY` | Content of `catalog-signing.key` (optional) |
| `MYDEX_CATALOG_PUBLIC_KEY` | Public key from step 2 (optional) |

## 4. Create the tag

On the current `main`:

```sh
git checkout main && git pull
git tag v1.0.0 && git push origin v1.0.0
```

The “Release” workflow builds all packages and creates a **draft release** (contents: see
`README.md` in this folder).

## 5. Acceptance and publication

1. Load `mydex-1.0.0-android.apk` from the draft onto the GrapheneOS device and check it
   according to `grapheneos-acceptance.md`.
2. Optional: set up the sync server from `mydex-sync-server-…`, unpack
   `mydex-catalog-update-1.0.0.tar.gz` into `/var/lib/mydex/catalog` and start it with
   `--catalog-dir`.
3. Publish the draft on GitHub. For later updates via Obtainium, add the repository as a source
   (private repository: Obtainium needs a GitHub token for that).

## Not included

iOS, macOS and Windows signing need developer accounts with Apple or a code-signing
certificate; until then these packages are unsigned (see `README.md`).
