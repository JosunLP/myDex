# 0009 – Team-Prüfung ohne Legalitätsgarantie

Status: angenommen

## Kontext
Der Plan verlangt eine Legalitätsprüfung, die bei unvollständiger Transfer- oder
Eventmodellierung keine vollständige Garantie behauptet.

## Entscheidung
Teams gehören zu genau einem Spiel; alle Prüfungen laufen im Kontext dieses Spiels, nicht des
global gewählten. `TeamEvaluator` (application) liefert je Mitglied und Team einen von vier
Zuständen – die Reihenfolge ist zugleich die Schwere:

| Zustand | Bedeutung |
|---|---|
| gültig | Alle erfassten Regeln sind erfüllt. |
| teilweise geprüft | Etwas ist nur außerhalb der erfassten Wege möglich, z. B. eine Attacke, die im Lernset dieses Spiels fehlt (Event/Transfer denkbar). |
| Datenlage unzureichend | Für eine Aussage fehlen Daten (Form-, Lernset- oder Itemlücke). |
| ungültig | Verstoß gegen eine erfasste Regel (Form nicht im Spiel, Fähigkeit passt nicht, Item nicht tragbar, Wesen/Fähigkeiten/Items im Spiel nicht vorhanden, Attacke existiert nicht, IV/EV außerhalb des Bereichs, zu viele Mitglieder). |

Die App nennt immer, was geprüft wurde und was nicht (Events, Transfers,
Kombinationsbeschränkungen).

## Analyse und Vorschläge
Basistypen-Analyse aus Typen und gewählten Schadensattacken. Vorschläge sind deterministisch:
Für jede offensive Lücke wird die stärkste im Spiel erlernbare Schadensattacke eines
Teammitglieds gesucht, die den Typ sehr effektiv trifft. Keine KI.

## Konsequenzen
- Items gelten als tragbar, wenn sie laut Quelle in der Generation existieren und nicht in den
  Fächern „Basis-Items“ oder „Maschinen“ liegen; die Quelle markiert neuere Items nicht
  zuverlässig als tragbar.
- Let's Go (AVs) und Legends: Arceus (Effort Levels) werden mit der modernen Formel gerechnet;
  die App weist darauf hin.
