import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'backup_section.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  static const _dataLanguages = {'de': 'Deutsch', 'en': 'English'};

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
          heading(l10n.settingsDataLanguage),
          RadioGroup<String?>(
            groupValue: settings.dataLanguage,
            onChanged: controller.setDataLanguage,
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  title: Text(l10n.followUiLanguage),
                ),
                for (final MapEntry(:key, :value) in _dataLanguages.entries)
                  RadioListTile<String?>(value: key, title: Text(value)),
              ],
            ),
          ),
          heading(l10n.backupTitle),
          const BackupSection(),
          heading(l10n.aboutData),
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
