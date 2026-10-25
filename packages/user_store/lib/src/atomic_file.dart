import 'dart:io';

/// Schreibt [content] atomar: erst in eine temporäre Datei, dann Umbenennen.
/// Ein Absturz hinterlässt entweder die alte oder die vollständige neue Datei.
Future<void> writeFileAtomic(File file, String content) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  final raf = await tmp.open(mode: FileMode.write);
  try {
    await raf.writeString(content);
    await raf.flush();
  } finally {
    await raf.close();
  }
  await tmp.rename(file.path);
}
