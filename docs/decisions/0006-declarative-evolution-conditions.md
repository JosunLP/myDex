# 0006 – Declarative evolution conditions

Status: accepted

## Decision
Evolution conditions are a validated tree of nodes (`allOf`, `anyOf`, `minLevel`, `useItem`,
`holdItem`, `timeOfDay`, `location`, `region`, `minFriendship`, `knowsMove`, `trade`, `gender`,
`special`). The UI renders localized text from it. Downloaded content is never executed as code.

## Consequences
Unknown node types make a catalog pack invalid. Rare special cases use `special` with a reviewed
explanation key.
