import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'protocol.dart';

/// Connection to the sync server.
abstract interface class SyncTransport {
  Future<SyncResponse> sync(SyncRequest request);

  /// Deletes all data of the account on the server.
  Future<void> deleteAccountData();
}

/// Source of signed catalog updates (your own sync server).
abstract interface class CatalogUpdateSource {
  /// Signed update description or `null` if none is offered.
  Future<Map<String, Object?>?> catalogUpdate();

  /// The gzip-compressed catalog pack.
  Future<List<int>> catalogPack();
}

/// HTTPS connection with an access token. Plain HTTP is only allowed for
/// local addresses (own machine, Android emulator).
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

  /// Throws `insecureConnection` if [url] is neither HTTPS nor local.
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
