import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class MyDexApp extends ConsumerStatefulWidget {
  const MyDexApp({super.key});

  @override
  ConsumerState<MyDexApp> createState() => _MyDexAppState();
}

class _MyDexAppState extends ConsumerState<MyDexApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final uiLanguage = ref.watch(settingsProvider.select((s) => s.uiLanguage));
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: uiLanguage == null ? null : Locale(uiLanguage),
      routerConfig: _router,
      builder: (context, child) => CatalogGate(child: child!),
    );
  }
}

/// Zeigt Laden/Fehler, bis der lokale Katalog bereitsteht.
class CatalogGate extends ConsumerWidget {
  const CatalogGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final l10n = AppLocalizations.of(context);
    return switch (catalog) {
      AsyncData() => child,
      AsyncError(:final error) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: Space.l),
                Text(
                  l10n.loadError,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Space.s),
                SelectableText('$error', textAlign: TextAlign.center),
                const SizedBox(height: Space.l),
                FilledButton(
                  onPressed: () => ref.invalidate(catalogProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
