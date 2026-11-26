import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/version.dart';

/// The version is declared in several places; a release needs all of them.
void main() {
  test('pubspec, CHANGELOG and AppStream metadata match the app version', () {
    final pubspec = RegExp(
      r'^version: (\d+\.\d+\.\d+)\+(\d+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    expect(pubspec.group(1), appVersion);
    final [major, minor, patch] = appVersion.split('.').map(int.parse).toList();
    expect(
      int.parse(pubspec.group(2)!),
      major * 100000 + minor * 1000 + patch,
      reason: 'Android versionCode X·100000 + Y·1000 + Z (docs/release)',
    );

    final changelog = File('../../CHANGELOG.md').readAsStringSync();
    final firstRelease = RegExp(
      r'^## \[(\d+\.\d+\.\d+)\] – (\d{4}-\d{2}-\d{2})$',
      multiLine: true,
    ).firstMatch(changelog)!;
    expect(firstRelease.group(1), appVersion, reason: 'newest release');

    final metainfo = File(
      'linux/packaging/metainfo/io.github.josunlp.mydex_app.metainfo.xml',
    ).readAsStringSync();
    expect(
      metainfo,
      contains(
        '<release version="$appVersion" date="${firstRelease.group(2)}"',
      ),
    );
  });
}
