# 0015 – Catalog updates via your own sync server

Status: accepted (extends ADR 0007 and ADR 0012)

## Context
Until now a new catalog only arrived with a new app version. The repository is private, so there
is no public download source. The “sync” flavor and the desktop builds talk to a self-hosted
server anyway. The default Android flavor stays without internet permission.

## Decision
- **Source:** your own sync server. With `serve --catalog-dir <dir>` it serves
  `GET /v1/catalog/update` (signed description) and `GET /v1/catalog/pack` (gzip pack), both only
  with a valid access token. Without a directory it answers 404.
- **Signature:** Ed25519 over the canonical JSON form of the pack manifest (sorted keys, no
  whitespace). The manifest contains revision, schema version, SHA-256, size and a **sequence
  number** (`sequence` = commit time of the data source · 10,000 + schema version · 100 + rules
  version; the rules version increases with every change to the derivation rules of ADR 0008).
- **Trust:** the public key is set at build time
  (`--dart-define=MYDEX_CATALOG_KEY=<base64>[,<base64>]`, several for key rotation). Without a
  key the feature is disabled; the server alone cannot install anything.
- **Accepted only if** the signature matches, the schema version matches the app and the
  sequence number is higher than the installed one (no rollback to older snapshots). Then the
  checks from ADR 0007 apply: checksum, size, integrity check, revision inside the pack, atomic
  switch, fallback to the previous version.
- **Startup:** the installed catalog is used if it has the same revision as the bundled one or a
  higher sequence number. An app update with a newer catalog therefore replaces an older network
  update.
- **Trigger:** manually under “Data status and coverage” (“Check”), only in flavors with network
  access and only while sync is connected.
- **Tools:** `data_pipeline keygen --out <file>` creates the key pair,
  `data_pipeline sign-update --key <file> --out <dir>` writes `update.json` and the pack. The
  release workflow does this when the secret `MYDEX_CATALOG_SIGNING_KEY` is set.

## Consequences
- New data (e.g. a new game within the same schema) no longer needs an app update.
- If the schema changes, an app update is still required; the app reports this.
- The private signing key is the root of trust: keep it separate from the server. If it is lost,
  a new key ships with the next app version.
- The “offline” flavor still gets catalog updates only via app updates.
