# 0004 – Pass the game context explicitly

Status: accepted

## Decision
Every rule-dependent query receives a `GameContext` (game version, version group, ruleset,
catalog revision). The language is an output parameter, not a semantic one. A generation alone
is not sufficient context.

## Consequences
Detail pages only show data of the selected game. Switching games updates all sections
consistently because all providers depend on the same context.

Extended by 0016: the default context is the version-independent International Pokédex.
