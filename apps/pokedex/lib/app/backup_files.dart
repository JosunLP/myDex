import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dateizugriff für Datensicherungen; in Tests austauschbar.
abstract interface class BackupFiles {
  /// `false`, wenn der Nutzer abgebrochen hat.
  Future<bool> save(Uint8List bytes, String fileName);

  /// `null`, wenn der Nutzer abgebrochen hat.
  Future<Uint8List?> open();
}

/// Nutzt die systemeigenen Dialoge (auf Android über das Storage Access
/// Framework, ohne Google-Dienste).
class PlatformBackupFiles implements BackupFiles {
  const PlatformBackupFiles();

  @override
  Future<bool> save(Uint8List bytes, String fileName) async =>
      await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      ) !=
      null;

  @override
  Future<Uint8List?> open() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    return files.first.readAsBytes();
  }
}

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => const PlatformBackupFiles(),
);
