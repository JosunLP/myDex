# Security

Please report vulnerabilities privately via
[GitHub Security Advisories](https://github.com/JosunLP/myDex/security/advisories/new),
not via public issues. Particularly relevant:

- Sync server (`tools/sync_server`): authentication, account separation, input validation.
- Sync encryption and backups: PBKDF2-HMAC-SHA256, AES-256-GCM, import.
- Catalog installation and updates: checksums, integrity checks, Ed25519 signatures.

Only the latest published version is supported.
