import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/motion.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'search_field.dart';

/// Colour accent of a generation in the game picker.
Color generationColor(int generation) => switch (generation) {
  1 => const Color(0xFFD9534F),
  2 => const Color(0xFFE0A526),
  3 => const Color(0xFF3FA66B),
  4 => const Color(0xFF4A86D8),
  5 => const Color(0xFF6E6E7A),
  6 => const Color(0xFF3C7DD9),
  7 => const Color(0xFFE5763B),
  8 => const Color(0xFF9B59B6),
  _ => const Color(0xFFC0392B),
};

/// The global Pokédex/game picker as a compact pill – the context is always
/// visible and one tap away.
class GameContextSelector extends ConsumerWidget {
  const GameContextSelector({super.key, this.expanded = false});

  /// Fills the available width (sidebar) instead of hugging its content.
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final national = ref.watch(isNationalProvider);
    final lang = dataLanguageOf(context, ref);
    final scheme = Theme.of(context).colorScheme;
    final name = ctx.version.name(lang);
    final label = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(
          national ? Icons.public : Icons.videogame_asset_outlined,
          size: 18,
          color: national ? scheme.primary : generationColor(ctx.generation),
        ),
        const SizedBox(width: Space.s),
        Flexible(
          fit: expanded ? FlexFit.tight : FlexFit.loose,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.short),
            child: Text(
              name,
              key: ValueKey(name),
              maxLines: expanded ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        const SizedBox(width: Space.xs),
        Icon(Icons.expand_more, size: 20, color: scheme.onSurfaceVariant),
      ],
    );
    return Tooltip(
      message: l10n.selectGame,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: '${l10n.selectGame}: $name',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: expanded ? double.infinity : 240,
            minHeight: 48,
          ),
          child: Material(
            color: scheme.surfaceContainerHigh,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showGamePicker(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.m,
                  vertical: Space.m,
                ),
                child: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Key of the game picker (tests, scrolling).
const gamePickerKey = ValueKey('gamePicker');

/// Opens the picker: a sheet on phones, a dialog on large screens.
Future<void> showGamePicker(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: const _GamePicker(),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => _GamePicker(controller: controller),
    ),
  );
}

class _GamePicker extends ConsumerStatefulWidget {
  const _GamePicker({this.controller});

  final ScrollController? controller;

  @override
  ConsumerState<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends ConsumerState<_GamePicker> {
  String _query = '';

  void _choose(GameVersionId id) {
    HapticFeedback.selectionClick();
    ref.read(settingsProvider.notifier).setGameVersion(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final ctx = ref.watch(gameContextProvider);
    final recent = ref.watch(settingsProvider.select((s) => s.recentGames));
    final lang = dataLanguageOf(context, ref);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final q = normalizeSearchText(_query);
    bool matches(GameVersion v) =>
        q.isEmpty || normalizeSearchText(v.name(lang)).contains(q);

    // Newest games first, grouped by generation.
    final byGeneration = <int, List<GameVersion>>{};
    for (final v in catalog.versions.reversed) {
      if (!matches(v)) continue;
      final gen = catalog.versionGroups[v.versionGroupId]!.generation;
      byGeneration.putIfAbsent(gen, () => []).add(v);
    }
    final recentVersions = [
      for (final id in recent) ?catalog.versionById(GameVersionId(id)),
    ];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.xl, Space.s),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );

    final national = catalog.national.version;
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.s, Space.xl, 0),
          child: Text(l10n.gamePickerTitle, style: textTheme.headlineSmall),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, 0),
          child: SearchField(
            hintText: l10n.gamePickerSearch,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
      ),
      if (q.isEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, 0),
            child: _NationalCard(
              title: national.name(lang),
              subtitle: l10n.nationalDexSubtitle,
              selected: ctx.versionId == national.id,
              onTap: () => _choose(national.id),
            ),
          ),
        ),
        if (recentVersions.isNotEmpty) ...[
          SliverToBoxAdapter(child: header(l10n.recentGames)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.l),
              child: Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final v in recentVersions)
                    ChoiceChip(
                      showCheckmark: false,
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: generationColor(
                          catalog.versionGroups[v.versionGroupId]!.generation,
                        ),
                      ),
                      label: Text(v.name(lang)),
                      selected: v.id == ctx.versionId,
                      onSelected: (_) => _choose(v.id),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
      for (final MapEntry(key: gen, value: versions)
          in byGeneration.entries) ...[
        SliverToBoxAdapter(child: header(l10n.generationLabel(gen))),
        SliverList.builder(
          itemCount: versions.length,
          itemBuilder: (context, i) {
            final v = versions[i];
            final group = catalog.versionGroups[v.versionGroupId]!;
            final selected = v.id == ctx.versionId;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s),
              child: ListTile(
                selected: selected,
                onTap: () => _choose(v.id),
                leading: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: generationColor(gen).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(Radii.s),
                  ),
                  child: Icon(
                    Icons.videogame_asset_outlined,
                    size: 20,
                    color: generationColor(gen),
                  ),
                ),
                title: Text(v.name(lang)),
                subtitle: group.hasData ? null : Text(l10n.noGameData),
                trailing: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: Motion.of(context, Motion.short),
                  child: Icon(Icons.check_circle, color: scheme.primary),
                ),
              ),
            );
          },
        ),
      ],
      if (q.isNotEmpty && byGeneration.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Text(l10n.noResults(_query), textAlign: TextAlign.center),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
    ];

    return Material(
      key: gamePickerKey,
      type: MaterialType.transparency,
      child: CustomScrollView(controller: widget.controller, slivers: slivers),
    );
  }
}

/// The International Pokédex as the prominent first choice.
class _NationalCard extends StatelessWidget {
  const _NationalCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.standard,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.l),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [DexColors.red, DexColors.redDark]
                : [scheme.surfaceContainerHigh, scheme.surfaceContainerHigh],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.l),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.18)
                          : scheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.public,
                      color: selected
                          ? Colors.white
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: Space.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            color: selected ? Colors.white : scheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: selected
                                ? Colors.white
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
