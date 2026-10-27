# Abnahme auf GrapheneOS

Abnahmekriterium aus dem Architekturentwurf: Betrieb ohne Google Play Services, ohne
Google-Login, Play Integrity oder Push-Zwang, ohne unnötige Berechtigungen. Automatisch geprüft
werden die Berechtigungen der APKs (CI, `tools/ci/check_apk_permissions.sh`); der Rest wird je
Release auf einem Gerät abgenommen und hier protokolliert.

## Vorbereitung
- Gerät mit aktuellem GrapheneOS, **Sandboxed Google Play nicht installiert**.
- APKs aus dem Release-Entwurf; Prüfsumme gegen `SHA256SUMS` vergleichen.
- Für „Vorlesen“: eine TTS-Engine aus F-Droid/Accrescent (z. B. RHVoice) installieren – und
  einmal ohne Engine testen.

## Prüfschritte – Ausgabe „myDex“ (offline)
| # | Schritt | Erwartung |
|---|---|---|
| 1 | Installation per `adb install` oder Dateimanager | Installiert ohne Hinweis auf fehlende Dienste |
| 2 | App-Info → Berechtigungen | Keine Berechtigungen; „Netzwerk“ nicht vorhanden |
| 3 | Erster Start im Flugmodus | Katalog wird installiert, Dex nutzbar |
| 4 | Pikachu suchen, Spiel auf Rot und auf Karmesin stellen | Typen/Werte wechseln, keine Fehlermeldung |
| 5 | Pikachu als gefangen markieren, App beenden, neu starten | Markierung bleibt |
| 6 | Team anlegen, Pokémon und Attacken wählen | Prüfung und Typanalyse erscheinen |
| 7 | Datensicherung mit Passwort exportieren (Speicherort wählen) und wieder importieren | Vorschau, Import erfolgreich, keine Speicherberechtigung angefragt |
| 8 | Vorlesen ohne TTS-Engine | Knopf deaktiviert mit Hinweis |
| 9 | Vorlesen mit RHVoice | Text wird gesprochen, Stopp funktioniert |
| 10 | Sprache auf Französisch stellen | Oberfläche und Namen französisch |
| 11 | „Mehr“ | Kein Eintrag „Synchronisierung“ |
| 12 | TalkBack einschalten, Dex und Detailseite bedienen | Alle Bedienelemente beschriftet und erreichbar |

## Prüfschritte – Ausgabe „myDex Sync“
| # | Schritt | Erwartung |
|---|---|---|
| 1 | Installation neben „myDex“ | Beide Apps parallel installiert |
| 2 | App-Info → Berechtigungen | Nur „Netzwerk“ |
| 3 | Mit eigenem Sync-Server verbinden (HTTPS) | „Verbunden und abgeglichen.“ |
| 4 | Team ändern, an zweitem Gerät abgleichen | Änderung kommt an |
| 5 | Netzwerk-Berechtigung in GrapheneOS entziehen, Team ändern | Fehlermeldung „nicht erreichbar“, Änderung bleibt wartend |
| 6 | Berechtigung zurückgeben, „Jetzt abgleichen“ | Änderung wird gesendet |

## Protokoll
| Version | Datum | Gerät / GrapheneOS-Build | Ergebnis | Anmerkungen |
|---|---|---|---|---|
| | | | | |
