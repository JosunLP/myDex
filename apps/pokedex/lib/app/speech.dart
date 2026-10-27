import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// The system's text-to-speech. Nothing is downloaded and nothing is
/// transmitted; without an engine the feature stays off.
abstract interface class Speaker {
  Future<bool> isAvailable();

  /// Speaks [text] in [language] (BCP 47) and completes when the output is
  /// finished or [stop] was called.
  Future<void> speak(String text, {required String language});

  Future<void> stop();
}

/// Android, iOS, macOS and Windows via the platform engines.
/// On GrapheneOS any installed TTS engine works (e.g. RHVoice).
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

/// Linux via Speech Dispatcher (`spd-say`) or eSpeak NG, if installed.
class LinuxSpeaker implements Speaker {
  Future<String?>? _command;
  Process? _process;

  Future<String?> _find() => _command ??= () async {
    for (final candidate in const ['spd-say', 'espeak-ng', 'espeak']) {
      try {
        final r = await Process.run('which', [candidate]);
        if (r.exitCode == 0) return candidate;
      } on Object {
        // `which` is missing – next candidate.
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
      // Also cancel output already handed to the service.
      unawaited(Process.run('spd-say', ['--cancel']).then((_) {}));
    }
  }
}

/// Without text-to-speech (e.g. web or tests).
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

/// Identifier of the content currently being spoken; `null` when silent.
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
      // Engine errors only end the output, not the app.
      debugPrint('Text-to-speech failed: $e');
    } finally {
      if (ref.mounted && state == id) state = null;
    }
  }

  Future<void> stop() async {
    state = null;
    await ref.read(speakerProvider).stop();
  }

  /// For `dispose`: stops the output of [id] after the current frame.
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
