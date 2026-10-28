# 0007 – Catalog as a SQLite pack via `sqlite3`, without Drift

Status: accepted · extends ADR 0003

## Context
ADR 0003 originally planned Drift for both databases. The catalog, however, is written only by
the pipeline and only read by the app; it needs neither migrations nor reactive queries nor code
generation.

## Decision
- The catalog is a SQLite file (schema in `packages/catalog_store/lib/src/schema.dart`) that the
  pipeline produces and the app opens read-only with the `sqlite3` package (`immutable=1`, no
  journal or lock files).
- Via build hooks, `sqlite3` bundles its own SQLite with FTS5 on all target platforms; no system
  SQLite and no `sqlite3_flutter_libs` are needed.
- Core data (species, forms, profiles, names) is loaded into memory in a background isolate at
  startup (`CatalogSnapshot`); large tables (learnsets, move data, search) are queried on demand
  (`CatalogDetails`).
- Drift remains the option for user data once migrations or sync require it.

## Consequences
- One dependency less and no code generation in the build.
- Pipeline and app share the same schema as a Dart constant.
- Schema changes bump `catalogSchemaVersion`; older packs are rejected.
