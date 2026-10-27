# 0003 – Store catalog and user data separately

Status: accepted · catalog part refined by ADR 0007

## Decision
The public catalog is read-only and replaced as a whole. Personal data (collection, teams,
filters, settings) lives in its own store. Both are linked via stable IDs; the application
checks consistency.

Catalog: SQLite pack, read-only, installed under `catalog/` (ADR 0007).
User data: for now atomically written JSON files behind repository interfaces; a database
follows once migrations or sync require it.

## Consequences
Catalog updates can never overwrite personal data. Orphaned IDs after an update are shown, not
deleted.
