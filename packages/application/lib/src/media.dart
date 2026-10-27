import 'dart:typed_data';

import 'package:mydex_domain/mydex_domain.dart';

/// Ein Bild einer Form: Standard-Sprite ([slot] leer) oder das eines Spiels.
typedef SpriteKey = ({FormId form, String slot, bool shiny});

/// Bilder zu Formen (Sprites je Spiel). Fehlende Bilder sind normal und werden
/// in der Oberfläche durch einen Platzhalter ersetzt.
abstract interface class MediaLibrary {
  /// Sprite-Sätze in Spielreihenfolge, z. B. `red-blue`, `gold`.
  List<String> get slots;

  /// Versionen, die einen Sprite-Satz verwenden.
  List<GameVersionId> versionsOf(String slot);

  /// Sprite-Satz einer Spielversion, falls vorhanden.
  String? slotFor(GameVersionId version);

  bool has(FormId form, {String slot = '', bool shiny = false});

  /// Hauptfarbe des offiziellen Artworks als `0xRRGGBB`, falls vorhanden.
  int? artworkColor(FormId form);

  /// PNG-Daten oder `null`. Wiederholte Aufrufe liefern dieselbe Instanz,
  /// damit der Bild-Cache greift.
  Uint8List? sprite(FormId form, {String slot = '', bool shiny = false});

  /// Bestes Bild für ein Spiel: das des Spiels, sonst das Standard-Sprite.
  Uint8List? spriteFor(
    FormId form, {
    GameVersionId? version,
    bool shiny = false,
  });

  /// Alle vorhandenen Bilder einer Form, Standard zuerst.
  List<SpriteKey> spritesOf(FormId form);

  void close();
}

/// Ohne Medienpaket (z. B. beschädigt): alles fehlt, die App läuft weiter.
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
