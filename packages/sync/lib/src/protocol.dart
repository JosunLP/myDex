import 'package:meta/meta.dart';

/// Protokollversion; der Server lehnt unbekannte Versionen ab.
const syncProtocolVersion = 1;

/// Grenzen, die Client und Server gleichermaßen einhalten.
abstract final class SyncLimits {
  /// Höchstens so viele Änderungen je Anfrage und je Antwortseite.
  static const changesPerRequest = 500;

  /// Größte erlaubte Nutzlast eines Datensatzes (UTF-8, JSON).
  static const recordBytes = 64 * 1024;

  /// Größter Anfragekörper.
  static const requestBytes = 8 * 1024 * 1024;

  static const kindPattern = r'^[a-z][a-z0-9_]{0,31}$';
  static const idMaxLength = 256;
}

/// Ein Datensatz, wie ihn der Server kennt. Gelöschte Datensätze bleiben als
/// Grabstein (`deleted`) erhalten, damit andere Geräte die Löschung sehen.
@immutable
class SyncRecord {
  const SyncRecord({
    required this.kind,
    required this.id,
    required this.revision,
    required this.updatedAt,
    this.deleted = false,
    this.data,
  });

  factory SyncRecord.fromJson(Map<String, Object?> j) => SyncRecord(
    kind: j['kind']! as String,
    id: j['id']! as String,
    revision: j['revision']! as int,
    updatedAt: DateTime.parse(j['updatedAt']! as String),
    deleted: (j['deleted'] as bool?) ?? false,
    data: j['data'] as Map<String, Object?>?,
  );

  final String kind;
  final String id;

  /// Kontoweit fortlaufend; steigt mit jeder angenommenen Änderung.
  final int revision;
  final DateTime updatedAt;
  final bool deleted;
  final Map<String, Object?>? data;

  String get key => recordKey(kind, id);

  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (deleted) 'deleted': true,
    if (!deleted) 'data': data,
  };
}

String recordKey(String kind, String id) => '$kind/$id';

/// Eine lokale Änderung. [baseRevision] ist die zuletzt bekannte
/// Server-Revision; weicht sie ab, meldet der Server einen Konflikt statt zu
/// überschreiben.
@immutable
class SyncChange {
  const SyncChange({
    required this.kind,
    required this.id,
    required this.updatedAt,
    this.baseRevision,
    this.deleted = false,
    this.data,
  });

  factory SyncChange.fromJson(Map<String, Object?> j) => SyncChange(
    kind: j['kind']! as String,
    id: j['id']! as String,
    baseRevision: j['baseRevision'] as int?,
    updatedAt: DateTime.parse(j['updatedAt']! as String),
    deleted: (j['deleted'] as bool?) ?? false,
    data: j['data'] as Map<String, Object?>?,
  );

  final String kind;
  final String id;
  final int? baseRevision;
  final DateTime updatedAt;
  final bool deleted;
  final Map<String, Object?>? data;

  String get key => recordKey(kind, id);

  SyncChange withBase(int? base) => SyncChange(
    kind: kind,
    id: id,
    baseRevision: base,
    updatedAt: updatedAt,
    deleted: deleted,
    data: data,
  );

  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    if (baseRevision != null) 'baseRevision': baseRevision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (deleted) 'deleted': true,
    if (!deleted) 'data': data,
  };
}

@immutable
class SyncRequest {
  const SyncRequest({required this.since, this.changes = const []});

  factory SyncRequest.fromJson(Map<String, Object?> j) {
    if (j['protocol'] != syncProtocolVersion) {
      throw const SyncProtocolException('unsupportedProtocol');
    }
    return SyncRequest(
      since: j['since']! as int,
      changes: [
        for (final c in (j['changes'] as List<Object?>?) ?? const [])
          SyncChange.fromJson(c! as Map<String, Object?>),
      ],
    );
  }

  /// Höchste bereits empfangene Revision.
  final int since;
  final List<SyncChange> changes;

  Map<String, Object?> toJson() => {
    'protocol': syncProtocolVersion,
    'since': since,
    'changes': [for (final c in changes) c.toJson()],
  };
}

enum SyncResultStatus { applied, conflict }

/// Ergebnis einer einzelnen eingereichten Änderung.
@immutable
class SyncResult {
  const SyncResult({
    required this.kind,
    required this.id,
    required this.status,
    this.revision,
    this.current,
  });

  factory SyncResult.fromJson(Map<String, Object?> j) => SyncResult(
    kind: j['kind']! as String,
    id: j['id']! as String,
    status: SyncResultStatus.values.byName(j['status']! as String),
    revision: j['revision'] as int?,
    current: j['current'] == null
        ? null
        : SyncRecord.fromJson(j['current']! as Map<String, Object?>),
  );

  final String kind;
  final String id;
  final SyncResultStatus status;

  /// Neue Revision bei `applied`.
  final int? revision;

  /// Aktueller Serverstand bei `conflict`.
  final SyncRecord? current;

  String get key => recordKey(kind, id);

  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'status': status.name,
    if (revision != null) 'revision': revision,
    if (current != null) 'current': current!.toJson(),
  };
}

@immutable
class SyncResponse {
  const SyncResponse({
    required this.cursor,
    this.results = const [],
    this.changes = const [],
    this.more = false,
  });

  factory SyncResponse.fromJson(Map<String, Object?> j) => SyncResponse(
    cursor: j['cursor']! as int,
    results: [
      for (final r in (j['results'] as List<Object?>?) ?? const [])
        SyncResult.fromJson(r! as Map<String, Object?>),
    ],
    changes: [
      for (final c in (j['changes'] as List<Object?>?) ?? const [])
        SyncRecord.fromJson(c! as Map<String, Object?>),
    ],
    more: (j['more'] as bool?) ?? false,
  );

  /// Neuer Stand für die nächste Anfrage (`since`).
  final int cursor;
  final List<SyncResult> results;

  /// Fremde Änderungen seit `since`, aufsteigend nach Revision.
  final List<SyncRecord> changes;

  /// Weitere Änderungen liegen bereit; sofort erneut abfragen.
  final bool more;

  Map<String, Object?> toJson() => {
    'protocol': syncProtocolVersion,
    'cursor': cursor,
    'results': [for (final r in results) r.toJson()],
    'changes': [for (final c in changes) c.toJson()],
    if (more) 'more': true,
  };
}

/// Fehler im Protokoll oder bei der Anmeldung; [code] ist stabil und wird in
/// der App übersetzt.
class SyncProtocolException implements Exception {
  const SyncProtocolException(this.code, [this.detail]);

  /// `unauthorized`, `unsupportedProtocol`, `invalidRequest`, `tooLarge`,
  /// `insecureConnection`, `server`, `network`.
  final String code;
  final String? detail;

  @override
  String toString() =>
      'SyncProtocolException($code${detail == null ? '' : ': $detail'})';
}
