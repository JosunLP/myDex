# 0009 – Team validation without a legality guarantee

Status: accepted

## Context
The plan calls for a legality check that does not claim a complete guarantee while transfers
and events are only partially modelled.

## Decision
Teams belong to exactly one game; all checks run in the context of that game, not the globally
selected one. `TeamEvaluator` (application) returns one of four states per member and team – the
order is also the severity:

| State | Meaning |
|---|---|
| valid | All recorded rules are satisfied. |
| partially checked | Something is only possible outside the recorded ways, e.g. a move missing from this game's learnset (event/transfer conceivable). |
| insufficient data | Data needed for a statement is missing (form, learnset or item gap). |
| invalid | A recorded rule is violated (form not in the game, ability does not match, item not holdable, natures/abilities/items do not exist in the game, move does not exist, IV/EV out of range, too many members). |

The app always states what was checked and what was not (events, transfers, combination
restrictions).

## Analysis and suggestions
Base type analysis from types and chosen damaging moves. Suggestions are deterministic: for each
offensive gap, the strongest damaging move learnable in the game by a team member that hits the
type super-effectively is chosen. No AI.

## Consequences
- Items count as holdable if they exist in the generation according to the source and are not
  in the “base items” or “machines” pockets; the source does not reliably mark newer items as
  holdable.
- Let's Go (AVs) and Legends: Arceus (effort levels) are calculated with the modern formula; the
  app points this out.
