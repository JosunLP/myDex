import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../brand/brand_mark.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/game_context_selector.dart';
import 'motion.dart';
import 'providers.dart';
import 'theme.dart';

/// Adaptive shell: bottom navigation (< 600), rail (600–999), sidebar (≥ 1000).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) {
    if (index != shell.currentIndex) HapticFeedback.selectionClick();
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final destinations = [
      (Icons.catching_pokemon_outlined, Icons.catching_pokemon, l10n.navDex),
      (Icons.map_outlined, Icons.map, l10n.navLocations),
      (Icons.inventory_2_outlined, Icons.inventory_2, l10n.navCollection),
      (Icons.groups_outlined, Icons.groups, l10n.navTeams),
      (Icons.tune_outlined, Icons.tune, l10n.navMore),
    ];
    final width = MediaQuery.sizeOf(context).width;

    if (width < Breakpoints.medium) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _select,
            animationDuration: Motion.of(context, Motion.medium),
            destinations: [
              for (final (icon, selected, label) in destinations)
                NavigationDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(selected),
                  label: label,
                ),
            ],
          ),
        ),
      );
    }

    final extended = width >= Breakpoints.expanded;
    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(right: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SafeArea(
              right: false,
              child: NavigationRail(
                minExtendedWidth: 232,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.s,
                    Space.l,
                    Space.s,
                    Space.xl,
                  ),
                  child: extended
                      ? const BrandLogo(size: 26)
                      : const BrandMark(size: 36),
                ),
                trailing: extended
                    ? const Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: Space.l),
                            child: _RailStatus(),
                          ),
                        ),
                      )
                    : null,
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
                      padding: const EdgeInsets.symmetric(vertical: 2),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

/// Context and offline state at the bottom of the sidebar.
class _RailStatus extends ConsumerWidget {
  const _RailStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GameContextSelector(expanded: true),
          const SizedBox(height: Space.m),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DexColors.ledGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Space.s),
                Flexible(child: Text(l10n.statusOffline, style: style)),
              ],
            ),
          ),
          const SizedBox(height: Space.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s),
            child: Text(
              l10n.statusRevision(ctx.contentRevision),
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Container of the section navigators: keeps every section alive (like an
/// IndexedStack) and lets the selected one fade through into view.
class AnimatedBranches extends StatelessWidget {
  const AnimatedBranches({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (i, child) in children.indexed)
        _Branch(active: i == index, child: child),
    ],
  );
}

class _Branch extends StatefulWidget {
  const _Branch({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Branch> createState() => _BranchState();
}

class _BranchState extends State<_Branch> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
    // The first visible section is shown without an animation.
    value: widget.active ? 1 : 0,
  );
  late final _curve = CurvedAnimation(parent: _controller, curve: Motion.enter);

  @override
  void didUpdateWidget(_Branch old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (Motion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    } else if (!widget.active && old.active) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !widget.active,
    // Like IndexedStack: hidden sections take no keyboard focus.
    child: ExcludeFocus(
      excluding: !widget.active,
      child: TickerMode(
        enabled: widget.active,
        child: FadeTransition(
          opacity: _curve,
          child: ScaleTransition(
            scale: Tween(begin: 0.985, end: 1.0).animate(_curve),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}
