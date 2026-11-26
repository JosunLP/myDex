import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../brand/brand_mark.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/motion.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../app/sync_controller.dart';
import 'backup_section.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  /// UI languages, each in its own spelling.
  static const uiLanguages = {
    'de': 'Deutsch',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'it': 'Italiano',
  };

  /// Languages of the game data in the catalog.
  static const dataLanguages = {
    'de': 'Deutsch',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'it': 'Italiano',
    'pt': 'Português',
    'ja': '日本語',
    'ja-Hrkt': '日本語 (かな)',
    'ko': '한국어',
    'zh-Hans': '简体中文',
    'zh-Hant': '繁體中文',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final catalog = ref.watch(readyCatalogProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    var index = 0;
    Widget group(String title, List<Widget> children) => Entrance(
      index: index++,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s, 0, Space.s, Space.s),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(color: scheme.primary),
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget link(
      IconData icon,
      String title,
      String? subtitle,
      VoidCallback onTap,
    ) => ListTile(
      leading: _IconBadge(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: EntranceScope(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.xxxl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Entrance(
                      index: index++,
                      child: TintBackdrop(
                        tint: DexColors.red,
                        strength: 0.6,
                        borderRadius: BorderRadius.circular(Radii.xl),
                        child: Padding(
                          padding: const EdgeInsets.all(Space.xl),
                          child: Row(
                            children: [
                              const AppIconArt(size: 64),
                              const SizedBox(width: Space.l),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.appTitle,
                                      style: textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.appTagline,
                                      style: textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: Space.xs),
                                    Text(
                                      l10n.aboutCatalog(catalog.revision),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    group(l10n.settingsTheme, [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.l,
                          vertical: Space.s,
                        ),
                        child: SegmentedButton<ThemeMode>(
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: const Icon(Icons.brightness_auto_outlined),
                              label: Text(l10n.themeSystem),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: const Icon(Icons.light_mode_outlined),
                              label: Text(l10n.themeLight),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: const Icon(Icons.dark_mode_outlined),
                              label: Text(l10n.themeDark),
                            ),
                          ],
                          showSelectedIcon: false,
                          selected: {settings.themeMode},
                          onSelectionChanged: (s) =>
                              controller.setThemeMode(s.single),
                        ),
                      ),
                      SwitchListTile(
                        secondary: const _IconBadge(Icons.animation),
                        title: Text(l10n.reduceMotion),
                        subtitle: Text(l10n.reduceMotionHint),
                        value: settings.reduceMotion,
                        onChanged: controller.setReduceMotion,
                      ),
                    ]),
                    group(l10n.settingsLanguage, [
                      _LanguageTile(
                        label: l10n.settingsUiLanguage,
                        followLabel: l10n.followSystemLanguage,
                        value: settings.uiLanguage,
                        options: uiLanguages,
                        onChanged: controller.setUiLanguage,
                      ),
                      _LanguageTile(
                        label: l10n.settingsDataLanguage,
                        followLabel: l10n.followUiLanguage,
                        value: settings.dataLanguage,
                        options: dataLanguages,
                        onChanged: controller.setDataLanguage,
                      ),
                    ]),
                    group(l10n.backupTitle, const [BackupSection()]),
                    if (ref.watch(syncSupportedProvider))
                      group(l10n.syncTitle, const [_SyncTile()]),
                    group(l10n.aboutData, [
                      link(
                        Icons.help_outline,
                        l10n.helpTitle,
                        l10n.helpSubtitle,
                        () => context.go('/more/help'),
                      ),
                      link(
                        Icons.offline_pin_outlined,
                        l10n.dataSources,
                        l10n.aboutCatalog(catalog.revision),
                        () => context.go('/more/data'),
                      ),
                      ListTile(
                        leading: const _IconBadge(Icons.description_outlined),
                        title: Text(
                          MaterialLocalizations.of(
                            context,
                          ).viewLicensesButtonLabel,
                        ),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: l10n.appTitle,
                          applicationIcon: const Padding(
                            padding: EdgeInsets.all(Space.s),
                            child: AppIconArt(size: 56),
                          ),
                        ),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.s,
                        Space.xl,
                        Space.s,
                        0,
                      ),
                      child: Text(
                        l10n.disclaimer,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon on a small tinted square (settings rows).
class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Radii.s),
      ),
      child: Icon(icon, size: 20, color: scheme.onSecondaryContainer),
    );
  }
}

/// Language choice as a dropdown; `null` follows the parent language.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.followLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String followLabel;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.s),
    child: DropdownButtonFormField<String?>(
      // Rebuild when the value changes from outside (import).
      key: ValueKey(value),
      // Unknown values (e.g. from a newer backup) count as "follow".
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text(followLabel)),
        for (final MapEntry(:key, :value) in options.entries)
          DropdownMenuItem(
            value: key,
            child: Text(
              value,
              locale: Locale.fromSubtags(languageCode: key.split('-').first),
            ),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}

class _SyncTile extends ConsumerWidget {
  const _SyncTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(syncProvider);
    return ListTile(
      leading: _IconBadge(
        status.connected ? Icons.cloud_sync_outlined : Icons.cloud_off_outlined,
      ),
      title: Text(l10n.syncTitle),
      subtitle: Text(
        status.connected
            ? l10n.syncSubtitleOn(Uri.parse(status.config!.serverUrl).host)
            : l10n.syncSubtitleOff,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/more/sync'),
    );
  }
}
