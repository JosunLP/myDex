import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'protocol.dart';
import 'server_core.dart';

/// Maps an access token to an account; `null` = unknown.
typedef SyncAuthenticator = String? Function(String token);

/// HTTP interface of the sync server:
/// - `GET  /v1/health`  – reachability and protocol version
/// - `POST /v1/sync`    – send and fetch changes
/// - `DELETE /v1/account` – delete all data of the account
/// - `GET  /v1/catalog/update`, `/v1/catalog/pack` – signed catalog updates
///
/// TLS is handled by a reverse proxy in front; without one, run it locally only.
class SyncHttpHandler {
  SyncHttpHandler(this.core, this.authenticate, {this.catalogDirectory});

  final SyncServerCore core;
  final SyncAuthenticator authenticate;

  /// Directory with `update.json` and `catalog.sqlite.gz` for signed catalog
  /// updates (ADR 0015); `null` = no updates offered.
  final Directory? catalogDirectory;

  Future<void> call(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..contentType = ContentType.json
      ..set('cache-control', 'no-store');
    try {
      final path = request.uri.path;
      if (path == '/v1/health' && request.method == 'GET') {
        return await _send(response, 200, {
          'ok': true,
          'protocol': syncProtocolVersion,
        });
      }
      final account = _account(request);
      if (path == '/v1/sync' && request.method == 'POST') {
        final body = await _readBody(request);
        final syncRequest = SyncRequest.fromJson(
          jsonDecode(body) as Map<String, Object?>,
        );
        return await _send(
          response,
          200,
          core.handle(account, syncRequest).toJson(),
        );
      }
      if (path == '/v1/catalog/update' && request.method == 'GET') {
        final file = _catalogFile('update.json');
        if (file == null) {
          return await _send(response, 404, {'error': 'notFound'});
        }
        response.statusCode = 200;
        await response.addStream(file.openRead());
        return await response.close();
      }
      if (path == '/v1/catalog/pack' && request.method == 'GET') {
        final file = _catalogFile('catalog.sqlite.gz');
        if (file == null) {
          return await _send(response, 404, {'error': 'notFound'});
        }
        response
          ..statusCode = 200
          ..headers.contentType = ContentType('application', 'gzip')
          ..headers.contentLength = await file.length();
        await response.addStream(file.openRead());
        return await response.close();
      }
      if (path == '/v1/account' && request.method == 'DELETE') {
        core.wipe(account);
        return await _send(response, 200, {'ok': true});
      }
      return await _send(response, 404, {'error': 'notFound'});
    } on SyncProtocolException catch (e) {
      final status = switch (e.code) {
        'unauthorized' => 401,
        'tooLarge' => 413,
        _ => 400,
      };
      return await _send(response, status, {'error': e.code});
    } on FormatException {
      return await _send(response, 400, {'error': 'invalidRequest'});
    } on TypeError {
      return await _send(response, 400, {'error': 'invalidRequest'});
    } on Object catch (e, s) {
      stderr.writeln('Error on ${request.method} ${request.uri.path}: $e\n$s');
      return await _send(response, 500, {'error': 'server'});
    }
  }

  File? _catalogFile(String name) {
    final dir = catalogDirectory;
    if (dir == null) return null;
    final file = File('${dir.path}/$name');
    return file.existsSync() ? file : null;
  }

  String _account(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    const prefix = 'Bearer ';
    if (header == null || !header.startsWith(prefix)) {
      throw const SyncProtocolException('unauthorized');
    }
    final account = authenticate(header.substring(prefix.length).trim());
    if (account == null) throw const SyncProtocolException('unauthorized');
    return account;
  }

  static Future<String> _readBody(HttpRequest request) async {
    final declared = request.contentLength;
    if (declared > SyncLimits.requestBytes) {
      throw const SyncProtocolException('tooLarge');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in request) {
      bytes.add(chunk);
      if (bytes.length > SyncLimits.requestBytes) {
        throw const SyncProtocolException('tooLarge');
      }
    }
    return utf8.decode(bytes.takeBytes());
  }

  static Future<void> _send(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    response
      ..statusCode = status
      ..write(jsonEncode(body));
    await response.close();
  }
}
