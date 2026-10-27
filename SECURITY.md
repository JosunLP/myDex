# Sicherheit

Bitte melde Sicherheitslücken vertraulich über
[GitHub Security Advisories](https://github.com/JosunLP/myDex/security/advisories/new),
nicht über öffentliche Issues. Besonders relevant:

- Sync-Server (`tools/sync_server`): Authentifizierung, Kontentrennung, Eingabeprüfung.
- Datensicherung: Verschlüsselung (PBKDF2-HMAC-SHA256, AES-256-GCM) und Import.
- Katalog-Installation: Prüfsummen und Integritätsprüfung.

Unterstützt wird jeweils die neueste veröffentlichte Version.
