# Privacy

myDex is an unofficial fan project and works without an account and without internet access.

## What data does the app process?
- **Catalog** (Pokémon, moves, locations …): shipped with the app and read locally.
- **Your data** (collection, teams, filter presets, settings): stored only on your device, in
  the app's private directory.
- **No** analytics, crash reports, ads, trackers or device identifiers. The app never sends
  anything on its own.

## When does data leave the device?
Only when you trigger it yourself:
- **Backup:** you choose the location and, optionally, a password (AES-256-GCM).
- **Sync (optional):** collection, teams and filter presets are sent via HTTPS to a server whose
  address you enter – usually your own. Before that they are encrypted on the device with your
  sync passphrase (AES-256-GCM, end-to-end); the server only sees encrypted records, their
  number and modification times. “Delete my data on the server” removes them there. On Android,
  sync is only available in the “myDex Sync” edition; the default edition has no internet
  permission.
- **Catalog updates (optional):** editions with sync can download a signed catalog update from
  the same server. Only the request itself is visible to the server.
- **Read-aloud:** uses your device's text-to-speech. Whether it sends text to third parties
  depends on the installed engine (RHVoice and eSpeak NG work locally).

## Permissions
- Android “myDex”: none. Android “myDex Sync”: internet only.
- macOS: network access (only for the optional sync), user-selected files.

## Deletion
Uninstalling the app or clearing its data removes everything from the device.
