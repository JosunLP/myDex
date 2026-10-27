import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';

/// Compresses a catalog deterministically and writes the manifest.
CatalogPackManifest packCatalog({
  required File database,
  required File packOut,
  required File manifestOut,
  required String revision,
  required String source,
  required String sourceRevision,
  int schemaVersion = catalogSchemaVersion,
  int sequence = 0,
}) {
  final bytes = database.readAsBytesSync();
  final manifest = CatalogPackManifest(
    revision: revision,
    schemaVersion: schemaVersion,
    sha256: sha256.convert(bytes).toString(),
    size: bytes.length,
    source: source,
    sourceRevision: sourceRevision,
    sequence: sequence,
  );
  // No timestamp in the header: the same input gives the same file.
  packOut.writeAsBytesSync(GZipCodec(level: 9).encode(bytes));
  manifestOut.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
  );
  return manifest;
}
