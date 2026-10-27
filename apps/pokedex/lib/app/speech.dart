import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Sprachausgabe des Systems. Es wird nichts heruntergeladen und nichts
/// übertragen; fehlt eine Engine, bleibt die Funktion aus.
abstract interface class Speaker {
  Future<bool> isAvailable();

  /// Spricht [text] in [language] (BCP-47) und endet, wenn die Ausgabe fertig
  /// ist oder [stop] aufgerufen wurde.
  Future<void> speak(String text, {required String language});

  Future<void> stop();
}

/// Android, iOS, macOS und Windows über die Plattform-Engines.
/// Unter GrapheneOS reicht jede installierte TTS-Engine (z. B. RHVoice).
class PlatformSpeaker implements Speaker {
  final _tts = FlutterTts();
  bool _configured = false;

  @override
  Future<bool> isAvailable() async {
    try {
      final languages = await _tts.getLanguages;
      return languages is List && languages.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> speak(String text, {required String language}) async {
    if (!_configured) {
      await _tts.awaitSpeakCompletion(true);
      _configured = true;
    }
    await _tts.setLanguage(language);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// Linux über Speech Dispatcher (`spd-say`) oder eSpeak NG, falls installiert.
class LinuxSpeaker implements Speaker {
  Future<String?>? _command;
  Process? _process;

  Future<String?> _find() => _command ??= () async {
    for (final candidate in const ['spd-say', 'espeak-ng', 'espeak']) {
      try {
        final r = await Process.run('which', [candidate]);
        if (r.exitCode == 0) return candidate;
      } on Object {
        // `which` fehlt – nächster Kandidat.
      }
    }
    return null;
  }();

  @override
  Future<bool> isAvailable() async => await _find() != null;

  @override
  Future<void> speak(String text, {required String language}) async {
    final command = await _find();
    if (command == null) return;
    await stop();
    final lang = language.split(RegExp('[-_]')).first;
    final args = command == 'spd-say'
        ? ['--wait', '--language', lang, '--', text]
        : ['-v', lang, '--', text];
    final process = _process = await Process.start(command, args);
    await process.exitCode;
    if (identical(_process, process)) _process = null;
  }

  @override
  Future<void> stop() async {
    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill();
    if (await _find() == 'spd-say') {
      // Bereits an den Dienst übergebene Ausgabe ebenfalls abbrechen.
      unawaited(Process.run('spd-say', ['--cancel']).then((_) {}));
    }
  }
}

/// Ohne Sprachausgabe (z. B. Web oder Tests).
class NoSpeaker implements Speaker {
  const NoSpeaker();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> speak(String text, {required String language}) async {}

  @override
  Future<void> stop() async {}
}

Speaker _platformSpeaker() {
  if (kIsWeb) return const NoSpeaker();
  if (Platform.isLinux) return LinuxSpeaker();
  if (Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows) {
    return PlatformSpeaker();
  }
  return const NoSpeaker();
}

final speakerProvider = Provider<Speaker>((ref) {
  final speaker = _platformSpeaker();
  ref.onDispose(() => speaker.stop().ignore());
  return speaker;
});

final speechAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(speakerProvider).isAvailable(),
  retry: (_, _) => null,
);

/// Kennung des gerade gesprochenen Inhalts; `null`, wenn still.
class SpeechController extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> toggle(String id, String text, {required String language}) {
    if (state == id) return stop();
    return _speak(id, text, language);
  }

  Future<void> _speak(String id, String text, String language) async {
    final speaker = ref.read(speakerProvider);
    if (state != null) await speaker.stop();
    state = id;
    try {
      await speaker.speak(text, language: language);
    } on Object catch (e) {
      // Engine-Fehler beenden nur die Ausgabe, nicht die App.
      debugPrint('Sprachausgabe fehlgeschlagen: $e');
    } finally {
      if (ref.mounted && state == id) state = null;
    }
  }

  Future<void> stop() async {
    state = null;
    await ref.read(speakerProvider).stop();
  }

  /// Für `dispose`: beendet die Ausgabe von [id] nach dem aktuellen Frame.
  void stopLater(String id) {
    if (state != id) return;
    scheduleMicrotask(() {
      if (ref.mounted && state == id) stop().ignore();
    });
  }
}

final speechProvider = NotifierProvider<SpeechController, String?>(
  SpeechController.new,
);
