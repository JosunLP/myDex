import 'dart:io';

/// Writes [content] atomically: first to a temporary file, then renames it.
/// A crash leaves either the old or the complete new file.
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
