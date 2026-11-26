import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/motion.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'motion.dart';

/// "Caught" switch for a form in the current context (game or the
/// International Pokédex). Pops with a little bounce when marked.
class CaughtButton extends ConsumerWidget {
  const CaughtButton({super.key, required this.form, this.shiny = false});

  final FormId form;
  final bool shiny;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final scheme = Theme.of(context).colorScheme;
    final key = CollectionKey(
      scope: collectionScopeOf(ctx),
      form: form,
      shiny: shiny,
    );
    final caught = ref.watch(
      collectionProvider.select((s) => s.value?[key]?.caught ?? false),
    );
    return IconButton(
      tooltip: l10n.markCaught,
      isSelected: caught,
      icon: PopOnActivate(
        // Fresh per scope: switching the game never plays the pop.
        key: ValueKey(key.scope),
        active: caught,
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.short),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            caught
                ? (shiny ? Icons.auto_awesome : Icons.check_circle)
                : (shiny
                      ? Icons.auto_awesome_outlined
                      : Icons.check_circle_outline),
            key: ValueKey(caught),
            color: caught ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        ref.read(collectionProvider.notifier).setCaught(key, !caught);
      },
    );
  }
}

/// Collection status on the detail page: seen, caught, shiny.
class CollectionToggles extends ConsumerWidget {
  const CollectionToggles({super.key, required this.form});

  final FormId form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final entries = ref.watch(collectionProvider).value ?? const {};
    final controller = ref.read(collectionProvider.notifier);
    final scope = collectionScopeOf(ctx);
    CollectionKey k(bool shiny) =>
        CollectionKey(scope: scope, form: form, shiny: shiny);
    final normal = entries[k(false)];
    final shiny = entries[k(true)];

    Widget chip({
      required String label,
      required IconData icon,
      required IconData selectedIcon,
      required bool selected,
      required ValueChanged<bool> onSelected,
    }) => PopOnActivate(
      // Fresh per scope: switching the game never plays the pop.
      key: ValueKey((scope, label)),
      active: selected,
      child: FilterChip(
        showCheckmark: false,
        avatar: Icon(selected ? selectedIcon : icon, size: 18),
        label: Text(label),
        selected: selected,
        onSelected: (v) {
          HapticFeedback.lightImpact();
          onSelected(v);
        },
      ),
    );

    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      alignment: WrapAlignment.center,
      children: [
        chip(
          label: l10n.seen,
          icon: Icons.visibility_outlined,
          selectedIcon: Icons.visibility,
          selected: normal?.seen ?? false,
          onSelected: (v) => controller.setSeen(k(false), v),
        ),
        chip(
          label: l10n.caught,
          icon: Icons.check_circle_outline,
          selectedIcon: Icons.check_circle,
          selected: normal?.caught ?? false,
          onSelected: (v) => controller.setCaught(k(false), v),
        ),
        chip(
          label: l10n.shiny,
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome,
          selected: shiny?.caught ?? false,
          onSelected: (v) => controller.setCaught(k(true), v),
        ),
      ],
    );
  }
}
