import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/providers.dart';

/// Sprite of a form – in the selected game that game's sprite, otherwise the
/// default sprite. Pixel art is scaled without smoothing. Purely decorative:
/// the name is always shown next to it.
class FormSprite extends ConsumerWidget {
  const FormSprite(
    this.form, {
    super.key,
    this.size = 40,
    this.shiny = false,
    this.version,
    this.slot,
    this.semanticLabel,
  });

  final FormId form;
  final double size;
  final bool shiny;

  /// Game version; if omitted, the globally selected one.
  final GameVersionId? version;

  /// Fixed sprite set (gallery); `''` = default sprite.
  final String? slot;

  /// Only set when the image stands alone (e.g. in the gallery).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaProvider).value;
    final bytes = media == null
        ? null
        : slot != null
        ? media.sprite(form, slot: slot!, shiny: shiny)
        : media.spriteFor(
            form,
            version: version ?? ref.watch(gameContextProvider).versionId,
            shiny: shiny,
          );
    if (bytes == null) return SizedBox.square(dimension: size);
    return Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
