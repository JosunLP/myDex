# 0011 – Read-aloud and languages

Status: accepted

## Decision
- **Read-aloud via the system's text-to-speech:** Android, iOS, macOS and Windows via
  `flutter_tts`, Linux via Speech Dispatcher (`spd-say`) or eSpeak NG as a process. No voice is
  downloaded and no text is sent to a service.
- **GrapheneOS:** no dependency on Google services. Any installed TTS engine works (e.g. RHVoice,
  eSpeak NG). For this the manifest declares only a `queries` entry for `TTS_SERVICE`, no
  permission.
- **Without an engine** the button stays visible but disabled, with a hint; the help names
  suitable engines.
- **Content:** a summary built from catalog facts of the selected game (name, number,
  availability, types, abilities, evolutions). Pokédex texts from the games are not read as long
  as they are not cleared in the rights inventory.
- **Language:** sentences and names in the app language so that the pronunciation matches the
  voice – regardless of a different data language.
- **UI languages:** German, English, French, Spanish, Italian; selectable or following the
  system. Game data in all eleven catalog languages, with a visible fallback when a translation
  is missing. English remains the template for new strings.

## Consequences
- Voice quality depends on the device and is not tested automatically (parity matrix: manual
  acceptance).
- New UI strings need translations into all five languages, otherwise generation fails.
