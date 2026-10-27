# 0014 – Ende-zu-Ende-Verschlüsselung des Sync

Status: angenommen (ergänzt ADR 0012)

## Kontext
ADR 0012 hat den Sync ohne Ende-zu-Ende-Verschlüsselung eingeführt; wer den Server betreibt,
konnte Sammlung, Teams und Vorlagen lesen. Da der Server nur speichert und vergleicht, braucht
er den Inhalt nicht zu kennen.

## Entscheidung
- **Pflicht für jede Verbindung:** Beim Verbinden wird ein Sync-Passwort (mindestens 8 Zeichen)
  verlangt. Es wird nicht gespeichert, nur die daraus abgeleiteten Schlüssel (im privaten
  App-Verzeichnis, wie Serveradresse und Zugangsschlüssel).
- **Schlüssel:** PBKDF2-HMAC-SHA256 (210 000 Runden, 16 Byte Salz) → 64 Byte: 32 für
  AES-256-GCM, 32 für HMAC-SHA256. Die Ableitung läuft in einem Hintergrund-Isolate.
- **Schlüsselprüfung:** Der Datensatz `keycheck/v1` enthält Salz, Runden und einen
  verschlüsselten Prüftext. Das erste Gerät legt ihn an; weitere Geräte leiten mit demselben
  Salz ab und prüfen den Text – ein abweichendes Passwort wird sofort erkannt.
  Ohne Protokolländerung: Der Datensatz wird mit Basisrevision „neu“ gesendet; existiert er,
  liefert der Konflikt den vorhandenen Stand.
- **Was der Server sieht:** Art `e`, eine undurchsichtige ID (HMAC über Art und ID),
  Revision, Zeitstempel, ob gelöscht, und einen Umschlag aus Nonce, Chiffrat und Tag.
  Die ID ist als Zusatzdaten an das Chiffrat gebunden; vertauschte oder veränderte Inhalte
  werden verworfen.
- **Löschungen:** Grabsteine tragen keinen Inhalt. Jedes Gerät führt eine lokale Zuordnung
  undurchsichtige ID → echte ID für alle gesendeten und empfangenen Datensätze.
- **Umsetzung als Transportschicht** (`EncryptingTransport`): Client, Konfliktlösung und Server
  bleiben unverändert.

## Konsequenzen
- Ein vergessenes Sync-Passwort lässt sich nicht wiederherstellen: „Meine Daten auf dem Server
  löschen“ und mit neuem Passwort neu verbinden; die Daten auf den Geräten bleiben erhalten.
- Metadaten bleiben sichtbar: Anzahl der Datensätze, Zeitpunkte von Änderungen, Größe.
- Das Passwort wechseln heißt derzeit: Serverdaten löschen und neu verbinden.
