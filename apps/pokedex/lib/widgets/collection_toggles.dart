import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/providers.dart';
import '../l10n/generated/app_localizations.dart';

/// "Caught" switch for a form in the current game.
class CaughtButton extends ConsumerWidget {
  const CaughtButton({super.key, required this.form, this.shiny = false});

  final FormId form;
  final bool shiny;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final key = CollectionKey(
      scope: GameScope(ctx.versionId),
      form: form,
      shiny: shiny,
    );
    final caught = ref.watch(
      collectionProvider.select((s) => s.value?[key]?.caught ?? false),
    );
    return IconButton(
      tooltip: l10n.markCaught,
      isSelected: caught,
      icon: Icon(
        shiny ? Icons.auto_awesome_outlined : Icons.check_circle_outline,
      ),
      selectedIcon: Icon(shiny ? Icons.auto_awesome : Icons.check_circle),
      onPressed: () =>
          ref.read(collectionProvider.notifier).setCaught(key, !caught),
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
    CollectionKey k(bool shiny) => CollectionKey(
      scope: GameScope(ctx.versionId),
      form: form,
      shiny: shiny,
    );
    final normal = entries[k(false)];
    final shiny = entries[k(true)];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text(l10n.seen),
          selected: normal?.seen ?? false,
          onSelected: (v) => controller.setSeen(k(false), v),
        ),
        FilterChip(
          label: Text(l10n.caught),
          selected: normal?.caught ?? false,
          onSelected: (v) => controller.setCaught(k(false), v),
        ),
        FilterChip(
          avatar: const Icon(Icons.auto_awesome, size: 18),
          label: Text(l10n.shiny),
          selected: shiny?.caught ?? false,
          onSelected: (v) => controller.setCaught(k(true), v),
        ),
      ],
    );
  }
}
