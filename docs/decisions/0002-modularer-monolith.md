# 0002 – Lokaler modularer Monolith

Status: angenommen

## Entscheidung
Die App enthält Katalog, Suche und Regeln lokal. Ein Server ist nur für optionalen Sync und die
statische Auslieferung signierter Datenpakete vorgesehen.

## Konsequenzen
Nachschlagen funktioniert ohne Netz und ohne Konto. Die Pipeline (`tools/`) liegt im selben
Repository und teilt die Domänenmodelle.
