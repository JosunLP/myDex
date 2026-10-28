# 0010 – Backup: format, encryption, import

Status: accepted

## Decision
- **Contents:** personal data only – collection, teams, filter presets, settings. The catalog is
  reproducible and does not belong in a backup.
- **Format:** JSON with `format: "mydex-backup"` and `version: 1`. Unknown versions are rejected;
  unreadable individual entries are skipped and counted in the preview.
- **Encryption (optional):** PBKDF2-HMAC-SHA256 (210,000 iterations, 16-byte salt) →
  AES-256-GCM. The parameters are stored in the file so they can be raised later. Without a
  password the file is readable by anyone who has it – the app says so.
- **Import:** always with a preview (new / updated / kept / removed per area).
  - *Merge:* per entry the newer state (`updatedAt`) wins, nothing is deleted, settings stay.
  - *Replace:* personal data matches the backup exactly afterwards.
- **File access:** native dialogs via `file_picker`; on Android the Storage Access Framework,
  without Google services and without storage permission.
- Key derivation and encryption run in a background isolate.

## Consequences
- No account and no server needed; the later sync (phase 4) complements it, it does not replace
  it.
- There is no password recovery: a forgotten password makes the file unreadable.
