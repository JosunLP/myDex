import 'package:meta/meta.dart';

import 'ids.dart';

/// Umfang einer Sammlungsmarkierung: ein bestimmtes Spiel oder global.
@immutable
sealed class CollectionScope {
  const CollectionScope();

  String get key;

  static CollectionScope parse(String key) {
    if (key == 'global') return const GlobalScope();
    if (key.startsWith('game:')) {
      return GameScope(GameVersionId(key.substring(5)));
    }
    throw FormatException('Unbekannter Sammlungsumfang: $key');
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionScope && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

final class GlobalScope extends CollectionScope {
  const GlobalScope();
  @override
  String get key => 'global';
}

final class GameScope extends CollectionScope {
  const GameScope(this.game);
  final GameVersionId game;
  @override
  String get key => 'game:${game.value}';
}

/// Eindeutiger Schlüssel eines Sammlungseintrags. Shiny ist eine Eigenschaft
/// des Eintrags, keine eigene Form.
@immutable
class CollectionKey {
  const CollectionKey({
    required this.scope,
    required this.form,
    this.shiny = false,
  });

  final CollectionScope scope;
  final FormId form;
  final bool shiny;

  String get encoded =>
      '${scope.key}|${form.value}|${shiny ? 'shiny' : 'normal'}';

  static CollectionKey decode(String s) {
    final parts = s.split('|');
    if (parts.length != 3) {
      throw FormatException('Ungültiger Sammlungsschlüssel: $s');
    }
    return CollectionKey(
      scope: CollectionScope.parse(parts[0]),
      form: FormId(parts[1]),
      shiny: switch (parts[2]) {
        'shiny' => true,
        'normal' => false,
        _ => throw FormatException('Ungültige Shiny-Angabe: ${parts[2]}'),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionKey && other.encoded == encoded;

  @override
  int get hashCode => encoded.hashCode;
}

@immutable
class CollectionEntry {
  const CollectionEntry({
    required this.key,
    this.seen = false,
    this.caught = false,
    this.caughtAt,
    this.note,
    required this.updatedAt,
  });

  factory CollectionEntry.fromJson(Map<String, Object?> j) => CollectionEntry(
    key: CollectionKey.decode(j['key']! as String),
    seen: (j['seen'] as bool?) ?? false,
    caught: (j['caught'] as bool?) ?? false,
    caughtAt: j['caughtAt'] == null
        ? null
        : DateTime.parse(j['caughtAt']! as String),
    note: j['note'] as String?,
    updatedAt: DateTime.parse(j['updatedAt']! as String),
  );

  final CollectionKey key;
  final bool seen;
  final bool caught;
  final DateTime? caughtAt;
  final String? note;
  final DateTime updatedAt;

  bool get isEmpty => !seen && !caught && (note == null || note!.isEmpty);

  /// Gefangen impliziert gesehen; Entfernen von „gefangen“ löscht das Fangdatum.
  CollectionEntry withCaught(bool value, DateTime now) => CollectionEntry(
    key: key,
    seen: seen || value,
    caught: value,
    caughtAt: value ? (caughtAt ?? now) : null,
    note: note,
    updatedAt: now,
  );

  /// „Nicht gesehen“ impliziert „nicht gefangen“.
  CollectionEntry withSeen(bool value, DateTime now) => CollectionEntry(
    key: key,
    seen: value,
    caught: value && caught,
    caughtAt: value ? caughtAt : null,
    note: note,
    updatedAt: now,
  );

  Map<String, Object?> toJson() => {
    'key': key.encoded,
    'seen': seen,
    'caught': caught,
    if (caughtAt != null) 'caughtAt': caughtAt!.toUtc().toIso8601String(),
    if (note != null) 'note': note,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
