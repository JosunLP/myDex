import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../brand/brand_mark.dart';
import '../l10n/generated/app_localizations.dart';
import 'motion.dart';
import 'providers.dart';
import 'router.dart';
import 'sync_controller.dart';
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
    final reduceMotion = ref.watch(
      settingsProvider.select((s) => s.reduceMotion),
    );
    // Keeps sync active (automatically after changes and at startup).
    if (ref.watch(syncSupportedProvider)) ref.listen(syncProvider, (_, _) {});
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      themeAnimationDuration:
          reduceMotion ||
              WidgetsBinding
                  .instance
                  .platformDispatcher
                  .accessibilityFeatures
                  .disableAnimations
          ? Duration.zero
          : Motion.medium,
      themeAnimationCurve: Motion.standard,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: uiLanguage == null ? null : Locale(uiLanguage),
      routerConfig: _router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return MediaQuery(
          // "Reduce motion" in the app adds to the system setting.
          data: media.copyWith(
            disableAnimations: media.disableAnimations || reduceMotion,
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                    .copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: Colors.transparent,
                      systemNavigationBarContrastEnforced: false,
                    ),
            child: CatalogGate(child: child!),
          ),
        );
      },
    );
  }
}

/// Shows the animated brand screen (or an error) until the local catalog is
/// ready, then fades into the app. It continues the native splash screen
/// seamlessly: same colour, same mark.
class CatalogGate extends ConsumerStatefulWidget {
  const CatalogGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CatalogGate> createState() => _CatalogGateState();
}

class _CatalogGateState extends ConsumerState<CatalogGate> {
  /// The install error already reported (each one is shown once).
  Object? _reported;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final l10n = AppLocalizations.of(context);
    ref.read(appStorageProvider).conflictLabel = l10n.syncConflictLabel;
    // A newer catalog that could not be installed is reported once; the app
    // keeps working with the previous one.
    final installError = ref.watch(catalogInstallErrorProvider);
    if (installError != null && !identical(installError, _reported)) {
      _reported = installError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(l10n.installFallback),
            duration: const Duration(seconds: 8),
          ),
        );
      });
    }
    final child = widget.child;
    final Widget content = switch (catalog) {
      AsyncData() => KeyedSubtree(key: const ValueKey('app'), child: child),
      AsyncError(:final error) => _LoadError(
        key: const ValueKey('error'),
        error: error,
        onRetry: () => ref.invalidate(catalogProvider),
      ),
      _ => const _Splash(key: ValueKey('splash')),
    };
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.long),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 1.02, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: content,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? Theme.of(context).colorScheme.surface
        : DexColors.red;
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedBrandMark(size: 128),
            const SizedBox(height: Space.xl),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.loadingCatalog,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: Space.xl),
                Text(
                  l10n.loadError,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Space.m),
                Container(
                  padding: const EdgeInsets.all(Space.m),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(Radii.m),
                  ),
                  child: SelectableText(
                    '$error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: Space.xl),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
