# 0013 – Media pack (sprites)

Status: accepted

## Context
Image rights are cleared for private use (rights inventory). Images should be available offline,
also in the Android flavor without internet permission, and reflect the game context (ADR 0004).

## Decision
- **Source:** `PokeAPI/sprites`, pinned to a commit. Files at a commit are immutable; CI rebuilds
  the pack and compares it with the committed one.
- **Scope:** default and shiny sprite of every form plus the in-game sprites of Gen 1–5 (Gen 1–2
  in the transparent version, Gen 1 without shiny). Candidates are the forms not confirmed
  missing from the respective game – derived from the built catalog.
- **Gen 6–9** (addendum): X/Y and Omega Ruby/Alpha Sapphire as static sprites with shiny. From
  Gen 7 the source only has animated 3D models (0.1–6 MB per image, about 10 GB in total) or box
  icons. One still image per form and game is stored, without shiny: the first frame of the
  animation (Ultra Sun/Ultra Moon, also used for Sun/Moon) or the box icon (Let's Go,
  Sword/Shield, Brilliant Diamond/Shining Pearl, Legends: Arceus, Scarlet/Violet, Legends: Z-A,
  Champions). Transparent border trimmed, scaled down to at most 96 px, palette PNG; versioned as
  `s96-v1`. Only the result stays in the cache. Expansions use the images of their base game.
  The media pack is now about 51 MB.
- **Pack:** its own SQLite file with its own schema (`media`), shipped gzip-compressed with the
  app and installed through the same installer as the catalog (checksum, integrity, atomic
  switch), but in its own directory.
- **Independent of the catalog:** if the media pack is missing or fails, the app keeps running
  without images; images are never a prerequisite for data.
- **Display:** in the selected game its sprite, otherwise the default sprite. Pixel art without
  smoothing. Images next to a name are hidden from screen readers; in the gallery they carry a
  description (name, game, shiny).
- **Official artwork** (addendum): one per form in the `artwork` slot, scaled down to 256 px and
  stored as a PNG with a 256-colour palette: 224 entries for opaque colours (octree), 31 for
  semi-transparent edges (average colour per opacity level), one fully transparent. This keeps
  transparency and soft edges; about 17 KB instead of 120 KB per image, about 20 MB in total.
  The process is deterministic and versioned (`a256-v1`); the result is cached next to the
  original.
- **Artwork colour** (schema 2): the pipeline derives the main colour of each form's artwork
  (table `artwork_color`); it tints the background of the Pokédex screen and the list
  thumbnails. Only opaque pixels without outlines and highlights are counted, sorted into colour
  cubes and weighted by chroma; the result is the average of the heaviest cube. Versioned as
  `c1`, deterministic. Without a media pack the colour of the first type is used.
- **Not included:** shiny artwork and HOME renders.

## Consequences
- The app package grows by about 51 MB (installed somewhat more).
- The first media build downloads about 17,000 files; afterwards they are cached
  (`.dart_tool/sprites`, in CI via `actions/cache`).
