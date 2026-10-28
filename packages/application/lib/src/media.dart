import 'dart:typed_data';

import 'package:mydex_domain/mydex_domain.dart';

/// An image of a form: the default sprite ([slot] empty) or a game's sprite.
typedef SpriteKey = ({FormId form, String slot, bool shiny});

/// Images for forms (sprites per game). Missing images are normal and are
/// replaced by a placeholder in the UI.
abstract interface class MediaLibrary {
  /// Sprite sets in game order, e.g. `red-blue`, `gold`.
  List<String> get slots;

  /// Versions that use a sprite set.
  List<GameVersionId> versionsOf(String slot);

  /// Sprite set of a game version, if any.
  String? slotFor(GameVersionId version);

  bool has(FormId form, {String slot = '', bool shiny = false});

  /// Main colour of the official artwork as `0xRRGGBB`, if available.
  int? artworkColor(FormId form);

  /// PNG data or `null`. Repeated calls return the same instance so that the
  /// image cache works.
  Uint8List? sprite(FormId form, {String slot = '', bool shiny = false});

  /// Best image for a game: the game's own, otherwise the default sprite.
  Uint8List? spriteFor(
    FormId form, {
    GameVersionId? version,
    bool shiny = false,
  });

  /// All available images of a form, default first.
  List<SpriteKey> spritesOf(FormId form);

  void close();
}

/// Without a media pack (e.g. corrupted): everything is missing, the app keeps running.
class EmptyMediaLibrary implements MediaLibrary {
  const EmptyMediaLibrary();

  @override
  List<String> get slots => const [];

  @override
  List<GameVersionId> versionsOf(String slot) => const [];

  @override
  String? slotFor(GameVersionId version) => null;

  @override
  bool has(FormId form, {String slot = '', bool shiny = false}) => false;

  @override
  int? artworkColor(FormId form) => null;

  @override
  Uint8List? sprite(FormId form, {String slot = '', bool shiny = false}) =>
      null;

  @override
  Uint8List? spriteFor(
    FormId form, {
    GameVersionId? version,
    bool shiny = false,
  }) => null;

  @override
  List<SpriteKey> spritesOf(FormId form) => const [];

  @override
  void close() {}
}
