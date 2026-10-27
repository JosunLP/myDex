import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'backup_section.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  /// Oberflächensprachen, jeweils in ihrer eigenen Schreibweise.
  static const uiLanguages = {
    'de': 'Deutsch',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'it': 'Italiano',
  };

  /// Sprachen der Spieldaten im Katalog.
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

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.xl, Space.l, Space.s),
      child: Semantics(
        header: true,
        child: Text(text, style: textTheme.titleSmall),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        children: [
          heading(l10n.settingsTheme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => controller.setThemeMode(s.single),
            ),
          ),
          heading(l10n.settingsLanguage),
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
          heading(l10n.backupTitle),
          const BackupSection(),
          heading(l10n.aboutData),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l10n.helpTitle),
            subtitle: Text(l10n.helpSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/more/help'),
          ),
          ListTile(
            leading: const Icon(Icons.offline_pin_outlined),
            title: Text(l10n.dataSources),
            subtitle: Text(l10n.aboutCatalog(catalog.revision)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/more/data'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(
              MaterialLocalizations.of(context).viewLicensesButtonLabel,
            ),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Text(l10n.disclaimer, style: textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Sprachwahl als Auswahlliste; `null` folgt der übergeordneten Sprache.
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
      // Neu aufbauen, wenn sich der Wert von außen ändert (Import).
      key: ValueKey(value),
      // Unbekannte Werte (z. B. aus einer neueren Sicherung) wie „folgen“.
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
