import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';

/// Komprimiert einen Katalog deterministisch und schreibt das Manifest.
CatalogPackManifest packCatalog({
  required File database,
  required File packOut,
  required File manifestOut,
  required String revision,
  required String source,
  required String sourceRevision,
  int schemaVersion = catalogSchemaVersion,
}) {
  final bytes = database.readAsBytesSync();
  final manifest = CatalogPackManifest(
    revision: revision,
    schemaVersion: schemaVersion,
    sha256: sha256.convert(bytes).toString(),
    size: bytes.length,
    source: source,
    sourceRevision: sourceRevision,
  );
  // Ohne Zeitstempel im Header: gleiche Eingabe ergibt gleiche Datei.
  packOut.writeAsBytesSync(GZipCodec(level: 9).encode(bytes));
  manifestOut.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
  );
  return manifest;
}
