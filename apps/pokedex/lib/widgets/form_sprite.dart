import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/providers.dart';

/// Sprite einer Form – im gewählten Spiel dessen Sprite, sonst das Standard-
/// Sprite. Pixelgrafik wird ohne Glättung skaliert. Rein dekorativ: der Name
/// steht immer daneben.
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

  /// Spielversion; ohne Angabe die global gewählte.
  final GameVersionId? version;

  /// Fester Sprite-Satz (Galerie); `''` = Standard-Sprite.
  final String? slot;

  /// Nur setzen, wenn das Bild allein steht (z. B. in der Galerie).
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
