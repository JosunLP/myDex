import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// File access for backups; replaceable in tests.
abstract interface class BackupFiles {
  /// `false` if the user cancelled.
  Future<bool> save(Uint8List bytes, String fileName);

  /// `null` if the user cancelled.
  Future<Uint8List?> open();
}

/// Uses the native dialogs (on Android via the Storage Access Framework,
/// without Google services).
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
