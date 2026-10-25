# 0006 – Deklarative Entwicklungsbedingungen

Status: angenommen

## Entscheidung
Entwicklungsbedingungen sind ein validierter Baum aus Knoten (`allOf`, `anyOf`, `minLevel`,
`useItem`, `holdItem`, `timeOfDay`, `location`, `region`, `minFriendship`, `knowsMove`,
`trade`, `gender`, `special`). Die UI erzeugt daraus lokalisierte Texte. Heruntergeladene
Inhalte werden nie als Code ausgeführt.

## Konsequenzen
Unbekannte Knotentypen machen ein Katalogpaket ungültig. Seltene Sonderfälle nutzen `special`
mit einem geprüften Erklärungsschlüssel.
