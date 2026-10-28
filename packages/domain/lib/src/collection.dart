import 'package:meta/meta.dart';

import 'ids.dart';

/// Scope of a collection mark: a specific game or global.
@immutable
sealed class CollectionScope {
  const CollectionScope();

  String get key;

  static CollectionScope parse(String key) {
    if (key == 'global') return const GlobalScope();
    if (key.startsWith('game:')) {
      return GameScope(GameVersionId(key.substring(5)));
    }
    throw FormatException('Unknown collection scope: $key');
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

/// Unique key of a collection entry. Shiny is a property of the entry, not a
/// form of its own.
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
      throw FormatException('Invalid collection key: $s');
    }
    return CollectionKey(
      scope: CollectionScope.parse(parts[0]),
      form: FormId(parts[1]),
      shiny: switch (parts[2]) {
        'shiny' => true,
        'normal' => false,
        _ => throw FormatException('Invalid shiny flag: ${parts[2]}'),
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

  /// Caught implies seen; removing "caught" clears the catch date.
  CollectionEntry withCaught(bool value, DateTime now) => CollectionEntry(
    key: key,
    seen: seen || value,
    caught: value,
    caughtAt: value ? (caughtAt ?? now) : null,
    note: note,
    updatedAt: now,
  );

  /// "Not seen" implies "not caught".
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
