# Release

For the first release see `first-release.md` (step by step).

For the release being prepared see the checklist `X.Y.Z.md` in this folder (currently
`1.1.0.md`).

## Process
1. `main` is green (CI including the APK permission check and accessibility tests).
2. Prepare the release in a pull request and merge it:
   - `CHANGELOG.md`: rename “Unreleased” to `## [X.Y.Z] – YYYY-MM-DD` (summary and upgrade notes
     first – the section becomes the release notes) and add a new empty “Unreleased”.
   - `apps/pokedex/pubspec.yaml`: `version: X.Y.Z+<versionCode>`.
   - `apps/pokedex/lib/app/version.dart`: `appVersion` (shown under “More”).
   - `apps/pokedex/linux/packaging/metainfo/*.metainfo.xml`: a `<release>` with the same date.
   - `apps/pokedex/test/version_test.dart` checks that these agree.
3. Create the tag: `git tag vX.Y.Z && git push origin vX.Y.Z`. The workflow refuses tags that do
   not match `pubspec.yaml` or have no CHANGELOG section.
4. The “Release” workflow builds everything and creates a **draft release**:
   - `mydex-X.Y.Z-android.apk` (flavor “offline”, no permissions)
   - `mydex-sync-X.Y.Z-android.apk` (flavor “sync”, internet only)
   - `mydex-X.Y.Z-linux-x64.tar.gz`, `mydex-X.Y.Z-windows-x64.zip`, `mydex-X.Y.Z-macos.zip`
   - `mydex-sync-server-X.Y.Z-linux-x64.tar.gz`
   - `mydex-catalog-update-X.Y.Z.tar.gz` (only with a signing key, see below)
   - `SHA256SUMS`, `android-certificates.txt`
5. Acceptance according to `grapheneos-acceptance.md` with the draft APK.
6. Publish the draft release on GitHub.

Version numbers: `X.Y.Z` from the tag; Android `versionCode` = `X·100000 + Y·1000 + Z`.

## Android signing (once)
The key identifies the app permanently – without it no updates are possible. Store it safely and
additionally offline.

```sh
keytool -genkeypair -v -keystore mydex-release.jks -alias mydex \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 mydex-release.jks   # store the output as a secret
```

GitHub → Settings → Secrets and variables → Actions:

| Secret | Content |
|---|---|
| `MYDEX_KEYSTORE_BASE64` | Keystore, Base64-encoded |
| `MYDEX_KEYSTORE_PASSWORD` | Keystore password |
| `MYDEX_KEY_ALIAS` | Alias, e.g. `mydex` |
| `MYDEX_KEY_PASSWORD` | Key password |

Locally, use `apps/pokedex/android/key.properties` instead (never commit it):

```properties
storeFile=/absolute/path/mydex-release.jks
storePassword=…
keyAlias=mydex
keyPassword=…
```

Without a key, local release builds use the debug key; the release workflow then aborts
(`MYDEX_REQUIRE_SIGNING=true`) and additionally checks that no debug certificate is in the
package.

## Catalog updates (optional, ADR 0015)
So that the flavors with network access receive new catalog snapshots via your own sync server,
create a key pair once:

```sh
dart run tools/data_pipeline/bin/data_pipeline.dart keygen --out catalog-signing.key
```

| Secret | Content |
|---|---|
| `MYDEX_CATALOG_SIGNING_KEY` | Content of `catalog-signing.key` (private) |
| `MYDEX_CATALOG_PUBLIC_KEY` | The printed public key |

The release workflow builds the public key into the apps and attaches
`mydex-catalog-update-X.Y.Z.tar.gz`. Unpack it on the server and serve it with
`serve --catalog-dir <dir>`. A new catalog without an app release:

```sh
dart run tools/data_pipeline/bin/data_pipeline.dart sign-update \
  --key catalog-signing.key --out /var/lib/mydex/catalog
```

## Not automated
- **iOS:** needs an Apple developer account (signing, TestFlight/App Store).
- **macOS:** the package is not signed/notarized; Gatekeeper asks on first launch.
- **Windows:** not signed; SmartScreen may warn.
- **Distribution:** myDex is a private app. Releases are GitHub releases (install the APK
  directly, e.g. via Obtainium); no store or F-Droid publication.
