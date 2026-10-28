# 0014 – End-to-end encryption for sync

Status: accepted (extends ADR 0012)

## Context
ADR 0012 introduced sync without end-to-end encryption; whoever runs the server could read
collection, teams and presets. Since the server only stores and compares, it does not need to
know the content.

## Decision
- **Mandatory for every connection:** connecting asks for a sync passphrase (at least 8
  characters). It is not stored, only the keys derived from it (in the app's private directory,
  like the server address and access token).
- **Keys:** PBKDF2-HMAC-SHA256 (210,000 iterations, 16-byte salt) → 64 bytes: 32 for
  AES-256-GCM, 32 for HMAC-SHA256. Derivation runs in a background isolate.
- **Key check:** the record `keycheck/v1` holds the salt, the iterations and an encrypted check
  text. The first device creates it; further devices derive with the same salt and verify the
  text – a different passphrase is detected immediately. No protocol change: the record is sent
  with base revision “new”; if it exists, the conflict returns the existing state.
- **What the server sees:** kind `e`, an opaque ID (HMAC over kind and ID), revision, timestamp,
  whether deleted, and an envelope of nonce, ciphertext and tag. The ID is bound to the
  ciphertext as additional data; swapped or modified content is discarded.
- **Deletions:** tombstones carry no content. Every device keeps a local mapping opaque ID → real
  ID for all sent and received records.
- **Implemented as a transport layer** (`EncryptingTransport`): client, conflict resolution and
  server stay unchanged.

## Consequences
- A forgotten sync passphrase cannot be recovered: “Delete my data on the server” and reconnect
  with a new passphrase; the data on the devices is kept.
- Metadata stays visible: number of records, modification times, size.
- Changing the passphrase currently means deleting the server data and reconnecting.
