import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

/// Signierte Beschreibung eines Katalog-Updates (ADR 0015).
///
/// ```json
/// {"format":"mydex-catalog-update","version":1,
///  "manifest":{...Katalogpaket-Manifest...},
///  "keyId":"…","signature":"…"}
/// ```
/// Signiert wird die kanonische JSON-Form von `manifest` (Schlüssel sortiert,
/// ohne Leerzeichen) mit Ed25519. Das Manifest enthält Prüfsumme, Größe,
/// Schemaversion, Revision und Reihenfolge des Pakets.
abstract final class CatalogUpdateFormat {
  static const format = 'mydex-catalog-update';
  static const version = 1;
}

class CatalogUpdateException implements Exception {
  const CatalogUpdateException(this.code);

  /// `invalid`, `untrustedKey`, `badSignature`.
  final String code;

  @override
  String toString() => 'CatalogUpdateException($code)';
}

/// Schlüsselpaar zum Signieren (nur in der Release-Umgebung vorhanden).
@immutable
class CatalogSigningKey {
  const CatalogSigningKey(this.seed);

  /// 32 zufällige Byte.
  factory CatalogSigningKey.generate([Random? random]) {
    final rnd = random ?? Random.secure();
    return CatalogSigningKey(List.generate(32, (_) => rnd.nextInt(256)));
  }

  factory CatalogSigningKey.fromBase64(String text) =>
      CatalogSigningKey(base64Decode(text.trim()));

  final List<int> seed;

  String toBase64() => base64Encode(seed);

  Future<String> publicKeyBase64() async {
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    return base64Encode((await pair.extractPublicKey()).bytes);
  }
}

/// Kurze Kennung eines öffentlichen Schlüssels (erste 8 Byte von SHA-256).
Future<String> catalogKeyId(String publicKeyBase64) async {
  final hash = await Sha256().hash(base64Decode(publicKeyBase64));
  return base64Url.encode(hash.bytes.sublist(0, 8)).replaceAll('=', '');
}

/// JSON mit sortierten Schlüsseln, ohne Leerzeichen.
String canonicalJson(Object? value) {
  Object? sort(Object? v) => switch (v) {
    final Map<Object?, Object?> m => {
      for (final k in (m.keys.map((k) => k.toString()).toList()..sort()))
        k: sort(m[k]),
    },
    final List<Object?> l => [for (final e in l) sort(e)],
    _ => v,
  };
  return jsonEncode(sort(value));
}

/// Erstellt die signierte Update-Beschreibung zu [manifest].
Future<Map<String, Object?>> signCatalogUpdate(
  Map<String, Object?> manifest,
  CatalogSigningKey key,
) async {
  final algorithm = Ed25519();
  final pair = await algorithm.newKeyPairFromSeed(key.seed);
  final signature = await algorithm.sign(
    utf8.encode(canonicalJson(manifest)),
    keyPair: pair,
  );
  return {
    'format': CatalogUpdateFormat.format,
    'version': CatalogUpdateFormat.version,
    'manifest': manifest,
    'keyId': await catalogKeyId(await key.publicKeyBase64()),
    'signature': base64Encode(signature.bytes),
  };
}

/// Prüft Format und Signatur gegen die vertrauenswürdigen öffentlichen
/// Schlüssel und liefert das Manifest. Wirft [CatalogUpdateException].
Future<Map<String, Object?>> verifyCatalogUpdate(
  Map<String, Object?> update,
  List<String> trustedPublicKeys,
) async {
  if (update['format'] != CatalogUpdateFormat.format ||
      update['version'] != CatalogUpdateFormat.version ||
      update['manifest'] is! Map<String, Object?> ||
      update['signature'] is! String) {
    throw const CatalogUpdateException('invalid');
  }
  final manifest = update['manifest']! as Map<String, Object?>;
  final message = utf8.encode(canonicalJson(manifest));
  final List<int> signature;
  try {
    signature = base64Decode(update['signature']! as String);
  } on FormatException {
    throw const CatalogUpdateException('invalid');
  }
  if (trustedPublicKeys.isEmpty) {
    throw const CatalogUpdateException('untrustedKey');
  }
  for (final key in trustedPublicKeys) {
    final List<int> bytes;
    try {
      bytes = base64Decode(key.trim());
    } on FormatException {
      continue;
    }
    final ok = await Ed25519().verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(bytes, type: KeyPairType.ed25519),
      ),
    );
    if (ok) return manifest;
  }
  throw const CatalogUpdateException('badSignature');
}
