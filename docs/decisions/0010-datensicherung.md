# 0010 – Datensicherung: Format, Verschlüsselung, Import

Status: angenommen

## Entscheidung
- **Inhalt:** nur persönliche Daten – Sammlung, Teams, Filtervorlagen, Einstellungen. Der
  Katalog ist reproduzierbar und gehört nicht in die Sicherung.
- **Format:** JSON mit `format: "mydex-backup"` und `version: 1`. Unbekannte Versionen werden
  abgelehnt; unlesbare Einzeleinträge werden übersprungen und in der Vorschau gezählt.
- **Verschlüsselung (optional):** PBKDF2-HMAC-SHA256 (210 000 Runden, 16-Byte-Salz) → AES-256-GCM.
  Die Parameter stehen in der Datei, damit sie später angehoben werden können. Ohne Passwort ist
  die Datei für alle lesbar, die sie haben – die App sagt das.
- **Import:** immer mit Vorschau (neu / aktualisiert / behalten / entfernt je Bereich).
  - *Zusammenführen:* je Eintrag gewinnt der neuere Stand (`updatedAt`), nichts wird gelöscht,
    Einstellungen bleiben.
  - *Ersetzen:* persönliche Daten entsprechen danach genau der Sicherung.
- **Dateizugriff:** systemeigene Dialoge über `file_picker`; auf Android das Storage Access
  Framework, ohne Google-Dienste und ohne Speicherberechtigung.
- Schlüsselableitung und Verschlüsselung laufen in einem Hintergrund-Isolate.

## Konsequenzen
- Kein Konto und kein Server nötig; der spätere Sync (Phase 4) ergänzt, ersetzt aber nicht.
- Es gibt keine Passwort-Wiederherstellung: ein vergessenes Passwort macht die Datei unlesbar.
