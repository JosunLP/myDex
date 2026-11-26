# Acceptance on GrapheneOS

Acceptance criterion from the architecture draft: works without Google Play Services, without
mandatory Google login, Play Integrity or push, without unnecessary permissions. The APK
permissions are checked automatically (CI, `tools/ci/check_apk_permissions.sh`); everything else
is accepted per release on a device and recorded here.

UI texts are quoted in English; the app follows the system language.

## Preparation
- Device with current GrapheneOS, **sandboxed Google Play not installed**.
- APKs from the draft release; compare checksums against `SHA256SUMS`.
- For read-aloud: install a TTS engine from F-Droid/Accrescent (e.g. RHVoice) – and test once
  without an engine.

## Steps – edition “myDex” (offline)
| # | Step | Expectation |
|---|---|---|
| 1 | Install via `adb install` or a file manager | Installs without a hint about missing services |
| 2 | App info → Permissions | No permissions; “Network” not present |
| 3 | First start in airplane mode | Red splash with the myDex mark, then the Dex on the “International Pokédex” |
| 4 | Search Pikachu, set the game to Red and to Scarlet | Types/stats change, no error |
| 4a | Search Clefairy in the International Pokédex, open it | Type Fairy, “Data as of …” shows the source game |
| 4b | On Pikachu tap a game under “Locations and how to obtain”, then “Undo” | Switches to the game with its locations, undo returns |
| 4c | Swipe sideways on a Pokémon page, then use the back gesture | Next Pokémon; predictive back shows the list behind |
| 4d | Home screen with themed icons on, long-press the icon | Monochrome myDex icon; round/adaptive shape without clipping |
| 4e | “More” → “Reduce motion” | Transitions and entrances switch off immediately |
| 5 | Mark Pikachu as caught, close the app, restart | The mark is kept |
| 6 | Create a team, pick Pokémon and moves | Validation and type analysis appear |
| 7 | Export a backup with a password (choose a location) and import it again | Preview, import succeeds, no storage permission requested |
| 8 | Read-aloud without a TTS engine | Button disabled with a hint |
| 9 | Read-aloud with RHVoice | Text is spoken, stop works |
| 10 | Set the language to French | UI and names in French |
| 11 | “More” | No “Sync” entry |
| 12 | Turn on TalkBack, use the Dex and a detail page | All controls labelled and reachable |

## Steps – edition “myDex Sync”
| # | Step | Expectation |
|---|---|---|
| 1 | Install next to “myDex” | Both apps installed side by side |
| 2 | App info → Permissions | Only “Network” |
| 3 | Connect to your own sync server (HTTPS) | “Connected and synced.” |
| 4 | Change a team, sync on a second device | The change arrives |
| 5 | Revoke the network permission in GrapheneOS, change a team | Error “The server cannot be reached”, change stays pending |
| 6 | Grant the permission again, “Sync now” | The change is sent |
| 7 | “More” → “Data status and coverage” → “Check” (with a catalog update on the server) | Catalog is updated or reported as up to date |

## Log
| Version | Date | Device / GrapheneOS build | Result | Notes |
|---|---|---|---|---|
| | | | | |
