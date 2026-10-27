import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/form_artwork.dart';
import '../../widgets/form_sprite.dart';

/// All images of a form: default and per game, normal and shiny.
class GallerySection extends ConsumerWidget {
  const GallerySection({super.key, required this.form, required this.name});

  final FormId form;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final media = ref.watch(mediaProvider).value;
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    if (media == null) return const SizedBox.shrink();
    final keys = media.spritesOf(form);
    if (keys.isEmpty) return Text(l10n.galleryEmpty);

    String slotLabel(String slot) {
      if (slot.isEmpty) return l10n.galleryDefault;
      final names = <String>[];
      for (final v in media.versionsOf(slot)) {
        // Japanese first editions share the sprites with Red/Blue,
        // expansions with their base game.
        if (v.value.endsWith('-japan') ||
            v.value.startsWith('the-') ||
            v.value == 'mega-dimension') {
          continue;
        }
        final version = catalog.versions.where((x) => x.id == v).firstOrNull;
        if (version != null) names.add(version.name(lang));
      }
      return names.isEmpty ? slot : names.join(' / ');
    }

    final slots = [
      for (final k in keys)
        if (!k.shiny && k.slot != artworkSlot) k.slot,
    ];
    final hasArtwork = media.has(form, slot: artworkSlot);
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: Space.m,
      runSpacing: Space.m,
      children: [
        if (hasArtwork)
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(Space.s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FormArtwork(
                    form,
                    size: 192,
                    semanticLabel: l10n.gallerySprite(
                      name,
                      l10n.galleryArtwork,
                    ),
                  ),
                  Text(l10n.galleryArtwork, style: textTheme.labelSmall),
                ],
              ),
            ),
          ),
        for (final slot in slots)
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(Space.s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FormSprite(
                        form,
                        size: 96,
                        slot: slot,
                        semanticLabel: l10n.gallerySprite(
                          name,
                          slotLabel(slot),
                        ),
                      ),
                      if (media.has(form, slot: slot, shiny: true))
                        FormSprite(
                          form,
                          size: 96,
                          slot: slot,
                          shiny: true,
                          semanticLabel: l10n.gallerySpriteShiny(
                            name,
                            slotLabel(slot),
                          ),
                        ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 192),
                    child: Text(
                      slotLabel(slot),
                      style: textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
