# 0011 – Vorlesen und Sprachen

Status: angenommen

## Entscheidung
- **Vorlesen über die Sprachausgabe des Systems:** Android, iOS, macOS und Windows über
  `flutter_tts`, Linux über Speech Dispatcher (`spd-say`) oder eSpeak NG als Prozess. Es wird
  keine Stimme heruntergeladen und kein Text an einen Dienst gesendet.
- **GrapheneOS:** keine Abhängigkeit von Google-Diensten. Jede installierte TTS-Engine genügt
  (z. B. RHVoice, eSpeak NG). Das Manifest deklariert dafür nur eine `queries`-Abfrage auf
  `TTS_SERVICE`, keine Berechtigung.
- **Ohne Engine** bleibt der Knopf sichtbar, aber deaktiviert, mit Hinweis; die Hilfe nennt
  passende Engines.
- **Inhalt:** eine Zusammenfassung aus Katalogfakten des gewählten Spiels (Name, Nummer,
  Verfügbarkeit, Typen, Fähigkeiten, Entwicklungen). Pokédex-Texte aus den Spielen werden nicht
  vorgelesen, solange sie im Rechteinventar nicht freigegeben sind.
- **Sprache:** Sätze und Namen in der App-Sprache, damit die Aussprache zur Stimme passt –
  unabhängig von einer abweichend gewählten Datensprache.
- **Oberflächensprachen:** Deutsch, Englisch, Französisch, Spanisch, Italienisch; wählbar oder
  nach System. Spieldaten in allen elf Katalogsprachen, mit sichtbarem Rückfall bei fehlender
  Übersetzung. Englisch bleibt Vorlage für neue Texte.

## Konsequenzen
- Die Qualität der Stimme hängt vom Gerät ab und wird nicht automatisch getestet (Paritätsmatrix:
  manuelle Abnahme).
- Neue Oberflächentexte brauchen Übersetzungen in alle fünf Sprachen, sonst schlägt die
  Generierung fehl.
