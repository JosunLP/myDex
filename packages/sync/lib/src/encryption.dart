import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import 'http_transport.dart';
import 'protocol.dart';

/// Ende-zu-Ende-Verschlüsselung des Abgleichs (ADR 0014).
///
/// Der Server sieht nur:
/// - die Art `e` und eine undurchsichtige ID (HMAC-SHA256 über Art und ID),
/// - Revision, Zeitstempel, ob gelöscht,
/// - einen verschlüsselten Umschlag (AES-256-GCM, die ID als Zusatzdaten).
/// Die Schlüssel stammen per PBKDF2 aus dem Sync-Passwort; das Salz liegt im
/// Datensatz `keycheck/v1`, zusammen mit einer Prüfsumme für das Passwort.
abstract final class SyncEncryption {
  static const kind = 'e';
  static const keycheckKind = 'keycheck';
  static const keycheckId = 'v1';
  static const defaultIterations = 210000;
  static const _checkText = 'mydex-sync-keycheck';
}

/// Schlüsselableitung; austauschbar, z. B. um sie in einem Isolate auszuführen.
typedef KeyDerivation =
    Future<SyncKey> Function(String passphrase, List<int> salt, int iterations);

/// Abgeleitete Schlüssel. Werden nach dem Entsperren lokal gespeichert, damit
/// das Passwort nicht bei jedem Start nötig ist.
@immutable
class SyncKey {
  const SyncKey({
    required this.encryption,
    required this.authentication,
    required this.salt,
    required this.iterations,
  });

  factory SyncKey.fromJson(Map<String, Object?> j) => SyncKey(
    encryption: base64Decode(j['enc']! as String),
    authentication: base64Decode(j['mac']! as String),
    salt: base64Decode(j['salt']! as String),
    iterations: j['iterations']! as int,
  );

  /// 32 Byte für AES-256-GCM.
  final List<int> encryption;

  /// 32 Byte für HMAC-SHA256 der IDs.
  final List<int> authentication;
  final List<int> salt;
  final int iterations;

  static Future<SyncKey> derive(
    String passphrase,
    List<int> salt,
    int iterations,
  ) async {
    final bits = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 512,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
    final bytes = await bits.extractBytes();
    return SyncKey(
      encryption: bytes.sublist(0, 32),
      authentication: bytes.sublist(32, 64),
      salt: salt,
      iterations: iterations,
    );
  }

  Map<String, Object?> toJson() => {
    'enc': base64Encode(encryption),
    'mac': base64Encode(authentication),
    'salt': base64Encode(salt),
    'iterations': iterations,
  };
}

/// Zuordnung undurchsichtiger IDs zu echten (`art/id`), nötig für Löschungen,
/// deren Grabsteine keinen Inhalt tragen.
abstract interface class SyncAliasStore {
  Future<Map<String, String>> load();
  Future<void> save(Map<String, String> aliases);
  Future<void> clear();
}

class MemorySyncAliasStore implements SyncAliasStore {
  Map<String, String> _aliases = {};

  @override
  Future<Map<String, String>> load() async => Map.of(_aliases);

  @override
  Future<void> save(Map<String, String> aliases) async =>
      _aliases = Map.of(aliases);

  @override
  Future<void> clear() async => _aliases = {};
}

class FileSyncAliasStore implements SyncAliasStore {
  FileSyncAliasStore(this.file);
  final File file;

  @override
  Future<Map<String, String>> load() async {
    try {
      if (!await file.exists()) return {};
      return (jsonDecode(await file.readAsString()) as Map<String, Object?>)
          .cast<String, String>();
    } on Object {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, String> aliases) =>
      writeFileAtomic(file, jsonEncode(aliases));

  @override
  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}

/// Verschlüsselt alle Datensätze auf dem Weg zum Server und entschlüsselt die
/// Antworten. Der Client darüber arbeitet unverändert mit Klartext.
class EncryptingTransport implements SyncTransport {
  EncryptingTransport(this.inner, this.key, this.aliases);

  final SyncTransport inner;
  final SyncKey key;
  final SyncAliasStore aliases;

  final _cipher = AesGcm.with256bits();
  final _hmac = Hmac.sha256();
  Map<String, String>? _map;

  /// Prüft das Sync-Passwort gegen den Server oder legt beim ersten Gerät die
  /// Schlüsselprüfung an. Wirft `wrongPassphrase` bei falschem Passwort.
  static Future<SyncKey> unlock(
    SyncTransport inner,
    String passphrase, {
    int iterations = SyncEncryption.defaultIterations,
    Random? random,
    KeyDerivation derive = SyncKey.derive,
  }) async {
    final rnd = random ?? Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final candidate = await derive(passphrase, salt, iterations);
    final check = await _sealCheck(candidate);
    var base = -1;
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await inner.sync(
        SyncRequest(
          // Keine fremden Änderungen mitladen.
          since: 1 << 52,
          changes: [
            SyncChange(
              kind: SyncEncryption.keycheckKind,
              id: SyncEncryption.keycheckId,
              baseRevision: base < 0 ? null : base,
              updatedAt: DateTime.now(),
              data: {
                'kdf': 'pbkdf2-hmac-sha256',
                'iterations': iterations,
                'salt': base64Encode(salt),
                'check': check,
              },
            ),
          ],
        ),
      );
      final result = response.results.single;
      if (result.status == SyncResultStatus.applied) return candidate;
      final current = result.current!;
      if (current.deleted || current.data == null) {
        base = current.revision;
        continue;
      }
      final data = current.data!;
      final existing = await derive(
        passphrase,
        base64Decode(data['salt']! as String),
        data['iterations']! as int,
      );
      if (!await _openCheck(existing, data['check']! as Map<String, Object?>)) {
        throw const SyncProtocolException('wrongPassphrase');
      }
      return existing;
    }
    throw const SyncProtocolException('server', 'keycheck');
  }

  static Future<Map<String, Object?>> _sealCheck(SyncKey key) async {
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(SyncEncryption._checkText),
      secretKey: SecretKey(key.encryption),
    );
    return _envelope(box);
  }

  static Future<bool> _openCheck(SyncKey key, Map<String, Object?> env) async {
    try {
      final plain = await AesGcm.with256bits().decrypt(
        _box(env),
        secretKey: SecretKey(key.encryption),
      );
      return utf8.decode(plain) == SyncEncryption._checkText;
    } on Object {
      return false;
    }
  }

  static Map<String, Object?> _envelope(SecretBox box) => {
    'n': base64Encode(box.nonce),
    'c': base64Encode(box.cipherText),
    'm': base64Encode(box.mac.bytes),
  };

  static SecretBox _box(Map<String, Object?> env) => SecretBox(
    base64Decode(env['c']! as String),
    nonce: base64Decode(env['n']! as String),
    mac: Mac(base64Decode(env['m']! as String)),
  );

  Future<Map<String, String>> _aliases() async => _map ??= await aliases.load();

  Future<String> _opaque(String kind, String id) async {
    final mac = await _hmac.calculateMac(
      utf8.encode('$kind/$id'),
      secretKey: SecretKey(key.authentication),
    );
    return base64Url.encode(mac.bytes).replaceAll('=', '');
  }

  Future<Map<String, Object?>> _seal(
    String opaque,
    String kind,
    String id,
    Map<String, Object?>? data,
  ) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode({'k': kind, 'i': id, 'd': data})),
      secretKey: SecretKey(key.encryption),
      aad: utf8.encode(opaque),
    );
    return _envelope(box);
  }

  /// Entschlüsselter Inhalt oder `null` (fremder Schlüssel, manipuliert).
  Future<({String kind, String id, Map<String, Object?>? data})?> _open(
    String opaque,
    Map<String, Object?> env,
  ) async {
    try {
      final plain = await _cipher.decrypt(
        _box(env),
        secretKey: SecretKey(key.encryption),
        aad: utf8.encode(opaque),
      );
      final j = jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
      return (
        kind: j['k']! as String,
        id: j['i']! as String,
        data: j['d'] as Map<String, Object?>?,
      );
    } on Object {
      return null;
    }
  }

  /// Klartext-Datensatz zu einem Serverdatensatz; `null`, wenn er nicht zu
  /// diesem Schlüssel gehört oder unbekannt gelöscht wurde.
  Future<SyncRecord?> _decryptRecord(SyncRecord r) async {
    if (r.kind != SyncEncryption.kind) return null;
    final map = await _aliases();
    if (r.deleted || r.data == null) {
      final real = map[r.id];
      if (real == null) return null;
      final slash = real.indexOf('/');
      return SyncRecord(
        kind: real.substring(0, slash),
        id: real.substring(slash + 1),
        revision: r.revision,
        updatedAt: r.updatedAt,
        deleted: true,
      );
    }
    final opened = await _open(r.id, r.data!);
    if (opened == null) return null;
    map[r.id] = recordKey(opened.kind, opened.id);
    return SyncRecord(
      kind: opened.kind,
      id: opened.id,
      revision: r.revision,
      updatedAt: r.updatedAt,
      deleted: opened.data == null,
      data: opened.data,
    );
  }

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    final map = await _aliases();
    final realByOpaque = <String, SyncChange>{};
    final changes = <SyncChange>[];
    for (final c in request.changes) {
      final opaque = await _opaque(c.kind, c.id);
      map[opaque] = c.key;
      realByOpaque[opaque] = c;
      changes.add(
        SyncChange(
          kind: SyncEncryption.kind,
          id: opaque,
          baseRevision: c.baseRevision,
          updatedAt: c.updatedAt,
          deleted: c.deleted,
          data: c.deleted ? null : await _seal(opaque, c.kind, c.id, c.data),
        ),
      );
    }
    final response = await inner.sync(
      SyncRequest(since: request.since, changes: changes),
    );

    final results = <SyncResult>[];
    for (final r in response.results) {
      final local = realByOpaque[r.id];
      if (local == null) continue;
      SyncRecord? current;
      if (r.current case final cur?) {
        current =
            await _decryptRecord(cur) ??
            // Nicht lesbar (z. B. anderer Schlüssel): wie gelöscht behandeln,
            // damit die lokale Fassung erhalten bleibt.
            SyncRecord(
              kind: local.kind,
              id: local.id,
              revision: cur.revision,
              updatedAt: cur.updatedAt,
              deleted: true,
            );
      }
      results.add(
        SyncResult(
          kind: local.kind,
          id: local.id,
          status: r.status,
          revision: r.revision,
          current: current,
        ),
      );
    }

    final incoming = <SyncRecord>[];
    for (final r in response.changes) {
      final record = await _decryptRecord(r);
      if (record != null) incoming.add(record);
    }
    await aliases.save(map);
    return SyncResponse(
      cursor: response.cursor,
      results: results,
      changes: incoming,
      more: response.more,
    );
  }

  @override
  Future<void> deleteAccountData() => inner.deleteAccountData();

  void close() {
    if (inner case final HttpSyncTransport http) http.close();
  }
}
