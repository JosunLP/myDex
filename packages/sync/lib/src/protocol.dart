import 'package:meta/meta.dart';

/// Protocol version; the server rejects unknown versions.
const syncProtocolVersion = 1;

/// Limits that client and server both respect.
abstract final class SyncLimits {
  /// At most this many changes per request and per response page.
  static const changesPerRequest = 500;

  /// Largest allowed payload of a record (UTF-8, JSON).
  static const recordBytes = 64 * 1024;

  /// Largest request body.
  static const requestBytes = 8 * 1024 * 1024;

  static const kindPattern = r'^[a-z][a-z0-9_]{0,31}$';
  static const idMaxLength = 256;
}

/// A record as the server knows it. Deleted records are kept as a tombstone
/// (`deleted`) so that other devices see the deletion.
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

  /// Increasing per account; grows with every accepted change.
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

/// A local change. [baseRevision] is the last known server revision; if it
/// differs, the server reports a conflict instead of overwriting.
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

  /// Highest revision received so far.
  final int since;
  final List<SyncChange> changes;

  Map<String, Object?> toJson() => {
    'protocol': syncProtocolVersion,
    'since': since,
    'changes': [for (final c in changes) c.toJson()],
  };
}

enum SyncResultStatus { applied, conflict }

/// Result of a single submitted change.
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

  /// New revision for `applied`.
  final int? revision;

  /// Current server state for `conflict`.
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

  /// New state for the next request (`since`).
  final int cursor;
  final List<SyncResult> results;

  /// Other devices' changes since `since`, ascending by revision.
  final List<SyncRecord> changes;

  /// More changes are available; fetch again right away.
  final bool more;

  Map<String, Object?> toJson() => {
    'protocol': syncProtocolVersion,
    'cursor': cursor,
    'results': [for (final r in results) r.toJson()],
    'changes': [for (final c in changes) c.toJson()],
    if (more) 'more': true,
  };
}

/// Error in the protocol or during authentication; [code] is stable and is
/// translated in the app.
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
