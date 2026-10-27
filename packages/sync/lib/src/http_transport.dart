import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'protocol.dart';

/// Verbindung zum Sync-Server.
abstract interface class SyncTransport {
  Future<SyncResponse> sync(SyncRequest request);

  /// Löscht alle Daten des Kontos auf dem Server.
  Future<void> deleteAccountData();
}

/// Quelle für signierte Katalog-Updates (der eigene Sync-Server).
abstract interface class CatalogUpdateSource {
  /// Signierte Update-Beschreibung oder `null`, wenn keine angeboten wird.
  Future<Map<String, Object?>?> catalogUpdate();

  /// Das gzip-komprimierte Katalogpaket.
  Future<List<int>> catalogPack();
}

/// HTTPS-Verbindung mit Zugangsschlüssel. Unverschlüsseltes HTTP ist nur für
/// lokale Adressen (eigener Rechner, Android-Emulator) erlaubt.
class HttpSyncTransport implements SyncTransport, CatalogUpdateSource {
  HttpSyncTransport(
    this.baseUrl,
    this.token, {
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? HttpClient() {
    checkServerUrl(baseUrl);
  }

  final Uri baseUrl;
  final String token;
  final Duration timeout;
  final HttpClient _client;

  static const _loopback = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};

  /// Wirft `insecureConnection`, wenn [url] weder HTTPS noch lokal ist.
  static void checkServerUrl(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      throw const SyncProtocolException('invalidRequest', 'url');
    }
    if (url.scheme == 'https') return;
    if (url.scheme == 'http' && _loopback.contains(url.host)) return;
    throw const SyncProtocolException('insecureConnection');
  }

  Uri _endpoint(String path) {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$base$path', query: null, fragment: null);
  }

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    final json = await _send('POST', '/v1/sync', jsonEncode(request.toJson()));
    return SyncResponse.fromJson(json);
  }

  @override
  Future<void> deleteAccountData() async {
    await _send('DELETE', '/v1/account', null);
  }

  @override
  Future<Map<String, Object?>?> catalogUpdate() async {
    try {
      return await _send('GET', '/v1/catalog/update', null);
    } on SyncProtocolException catch (e) {
      if (e.code == 'notFound') return null;
      rethrow;
    }
  }

  @override
  Future<List<int>> catalogPack({int maxBytes = 256 * 1024 * 1024}) async {
    try {
      final req = await _client
          .openUrl('GET', _endpoint('/v1/catalog/pack'))
          .timeout(timeout);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw SyncProtocolException(
          res.statusCode == 401 ? 'unauthorized' : 'server',
          'HTTP ${res.statusCode}',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(const Duration(minutes: 5))) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) {
          throw const SyncProtocolException('tooLarge');
        }
      }
      return bytes.takeBytes();
    } on SyncProtocolException {
      rethrow;
    } on IOException catch (e) {
      throw SyncProtocolException('network', '$e');
    } on TimeoutException {
      throw const SyncProtocolException('network', 'timeout');
    }
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path,
    String? body,
  ) async {
    try {
      final req = await _client
          .openUrl(method, _endpoint(path))
          .timeout(timeout);
      req.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(body));
      }
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      final decoded = text.isEmpty ? null : jsonDecode(text);
      if (res.statusCode == 200 && decoded is Map<String, Object?>) {
        return decoded;
      }
      final code = decoded is Map<String, Object?> && decoded['error'] is String
          ? decoded['error']! as String
          : (res.statusCode == 401 ? 'unauthorized' : 'server');
      throw SyncProtocolException(code, 'HTTP ${res.statusCode}');
    } on SyncProtocolException {
      rethrow;
    } on FormatException catch (e) {
      throw SyncProtocolException('server', e.message);
    } on HandshakeException catch (e) {
      throw SyncProtocolException('insecureConnection', e.message);
    } on IOException catch (e) {
      throw SyncProtocolException('network', '$e');
    } on TimeoutException {
      throw const SyncProtocolException('network', 'timeout');
    }
  }

  void close() => _client.close(force: true);
}
