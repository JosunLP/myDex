# 0004 – Spielkontext explizit weiterreichen

Status: angenommen

## Entscheidung
Jede regelabhängige Abfrage erhält einen `GameContext` (Spielversion, Spielgruppe, Regelwerk,
Katalogrevision). Die Sprache ist Ausgabe-, nicht Bedeutungsparameter. Eine Generation allein
genügt nicht als Kontext.

## Konsequenzen
Detailseiten zeigen nur Daten des gewählten Spiels. Ein Spielwechsel aktualisiert alle Bereiche
konsistent, weil alle Provider vom selben Kontext abhängen.
