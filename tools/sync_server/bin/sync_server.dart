import 'dart:io';

import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_sync_server/sync_server.dart';

const _usage = '''
myDex sync server

  serve           --db <file> [--host 127.0.0.1] [--port 8787]
                  [--catalog-dir <dir>]  serve signed catalog updates
  create-account  --db <file> --name <name>    prints the access token
  rotate-token    --db <file> --name <name>    new token, old one invalid
  delete-account  --db <file> --name <name>    delete account and its data
  list-accounts   --db <file>

The server only speaks HTTP. For devices on the network, put a reverse proxy
with TLS in front of it (see README); outside localhost the app requires HTTPS.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.write(_usage);
    exitCode = 64;
    return;
  }
  final options = <String, String>{};
  for (var i = 1; i < args.length - 1; i += 2) {
    if (!args[i].startsWith('--')) break;
    options[args[i].substring(2)] = args[i + 1];
  }
  final dbPath = options['db'];
  if (dbPath == null) {
    stderr.writeln('--db is missing.\n\n$_usage');
    exitCode = 64;
    return;
  }
  final db = openSyncDatabase(dbPath);
  final accounts = AccountRegistry(db);
  String name() =>
      options['name'] ?? (throw ArgumentError('--name is missing'));

  try {
    switch (args.first) {
      case 'serve':
        final host = options['host'] ?? '127.0.0.1';
        final port = int.parse(options['port'] ?? '8787');
        final catalogDir = options['catalog-dir'];
        final handler = SyncHttpHandler(
          SyncServerCore(SqliteSyncStore(db)),
          accounts.authenticate,
          catalogDirectory: catalogDir == null ? null : Directory(catalogDir),
        );
        final server = await HttpServer.bind(host, port);
        server.autoCompress = true;
        stdout.writeln('myDex sync listening on http://$host:$port');
        ProcessSignal.sigint.watch().listen((_) async {
          await server.close();
          db.close();
          exit(0);
        });
        await server.forEach(handler.call);
      case 'create-account':
        stdout.writeln(accounts.create(name()));
      case 'rotate-token':
        stdout.writeln(accounts.rotate(name()));
      case 'delete-account':
        if (!accounts.delete(name())) {
          stderr.writeln('Unknown account.');
          exitCode = 1;
        }
      case 'list-accounts':
        for (final a in accounts.list()) {
          stdout.writeln(
            '${a.name}\t${a.records} records\tsince ${a.createdAt}',
          );
        }
      default:
        stdout.write(_usage);
        exitCode = 64;
    }
  } on ArgumentError catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
  } finally {
    if (args.first != 'serve') db.close();
  }
}
