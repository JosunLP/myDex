# 0002 – Local modular monolith

Status: accepted

## Decision
The app contains the catalog, search and rules locally. A server is only intended for the
optional sync and for serving signed data packs.

## Consequences
Lookups work without a network and without an account. The pipeline (`tools/`) lives in the same
repository and shares the domain models.
