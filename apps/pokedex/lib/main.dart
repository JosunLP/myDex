import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // License notice of the data source (BSD-3 requires it when redistributing).
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'PokéAPI (catalog data)',
    ], await rootBundle.loadString('assets/licenses/pokeapi.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'PokeAPI/sprites (images)',
    ], await rootBundle.loadString('assets/licenses/sprites.txt'));
  });
  final dir = Directory(
    '${(await getApplicationSupportDirectory()).path}/mydex',
  );
  final storage = AppStorage(dir);
  await storage.sync.open();
  // Load the settings before the first frame so that theme and game do not jump.
  final settings = AppSettings.fromJson(await storage.preferences.load());
  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const MyDexApp(),
    ),
  );
}
