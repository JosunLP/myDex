import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';

/// Distinguishes data gaps from confirmed unavailability (ADR 0005).
class AvailabilityNotice extends StatelessWidget {
  const AvailabilityNotice({
    super.key,
    required this.availability,
    required this.pokemonName,
    required this.gameName,
  });

  final DataAvailability availability;
  final String pokemonName;
  final String gameName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, text, bg, fg) = switch (availability) {
      DataAvailability.confirmedAvailable => (null, null, null, null),
      DataAvailability.confirmedUnavailable => (
        Icons.block,
        l10n.availabilityConfirmedUnavailable(pokemonName, gameName),
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      DataAvailability.notApplicable => (
        Icons.remove_circle_outline,
        l10n.availabilityNotApplicable(gameName),
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      DataAvailability.unknown => (
        Icons.help_outline,
        l10n.availabilityUnknown(gameName),
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      DataAvailability.notResearched => (
        Icons.construction_outlined,
        l10n.availabilityNotResearched(gameName),
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    if (text == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(text, style: TextStyle(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small marker for lists.
class DataGapChip extends StatelessWidget {
  const DataGapChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.dataGap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_outlined, size: 16, color: scheme.tertiary),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              l10n.dataGap,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }
}
