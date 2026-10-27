import 'dart:io';

import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_sync_server/sync_server.dart';

const _usage = '''
myDex-Sync-Server

  serve           --db <datei> [--host 127.0.0.1] [--port 8787]
  create-account  --db <datei> --name <name>    gibt den Zugangsschlüssel aus
  rotate-token    --db <datei> --name <name>    neuer Schlüssel, alter ungültig
  delete-account  --db <datei> --name <name>    Konto samt Daten löschen
  list-accounts   --db <datei>

Der Server spricht nur HTTP. Für Geräte im Netz einen Reverse-Proxy mit TLS
vorschalten (siehe README); die App verlangt außerhalb von localhost HTTPS.
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
    stderr.writeln('--db fehlt.\n\n$_usage');
    exitCode = 64;
    return;
  }
  final db = openSyncDatabase(dbPath);
  final accounts = AccountRegistry(db);
  String name() => options['name'] ?? (throw ArgumentError('--name fehlt'));

  try {
    switch (args.first) {
      case 'serve':
        final host = options['host'] ?? '127.0.0.1';
        final port = int.parse(options['port'] ?? '8787');
        final handler = SyncHttpHandler(
          SyncServerCore(SqliteSyncStore(db)),
          accounts.authenticate,
        );
        final server = await HttpServer.bind(host, port);
        server.autoCompress = true;
        stdout.writeln('myDex-Sync lauscht auf http://$host:$port');
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
          stderr.writeln('Unbekanntes Konto.');
          exitCode = 1;
        }
      case 'list-accounts':
        for (final a in accounts.list()) {
          stdout.writeln(
            '${a.name}\t${a.records} Datensätze\tseit ${a.createdAt}',
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
