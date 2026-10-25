import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = Directory(
    '${(await getApplicationSupportDirectory()).path}/mydex',
  );
  final storage = AppStorage(dir);
  // Einstellungen vor dem ersten Frame laden, damit Theme und Spiel nicht springen.
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
