import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import 'providers.dart';
import 'theme.dart';

/// Adaptive Hülle: Bottom Navigation (< 600), Rail (600–999), Sidebar (≥ 1000).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (Icons.catching_pokemon_outlined, Icons.catching_pokemon, l10n.navDex),
      (Icons.map_outlined, Icons.map, l10n.navLocations),
      (Icons.checklist_outlined, Icons.checklist, l10n.navCollection),
      (Icons.groups_outlined, Icons.groups, l10n.navTeams),
      (Icons.more_horiz, Icons.more_horiz, l10n.navMore),
    ];
    final width = MediaQuery.sizeOf(context).width;

    if (width < Breakpoints.medium) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final (icon, selected, label) in destinations)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      );
    }

    final extended = width >= Breakpoints.expanded;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _select,
              destinations: [
                for (final (icon, selected, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: shell),
                if (extended) const _StatusBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final lang = dataLanguageOf(context, ref);
    final style = Theme.of(context).textTheme.bodySmall;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.l,
          vertical: Space.xs,
        ),
        child: DefaultTextStyle.merge(
          style: style,
          child: Row(
            children: [
              Text(l10n.statusGame(ctx.version.name(lang))),
              const Spacer(),
              Text(l10n.statusRevision(ctx.contentRevision)),
              const Spacer(),
              const Icon(Icons.offline_pin_outlined, size: 16),
              const SizedBox(width: Space.xs),
              Text(l10n.statusOffline),
            ],
          ),
        ),
      ),
    );
  }
}
