import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/providers.dart';
import 'form_sprite.dart';

/// Sprite set of the official artwork in the media pack.
const artworkSlot = 'artwork';

/// Official artwork of a form; without artwork the game's sprite.
class FormArtwork extends ConsumerWidget {
  const FormArtwork(
    this.form, {
    super.key,
    this.size = 200,
    this.semanticLabel,
  });

  final FormId form;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaProvider).value;
    final bytes = media?.sprite(form, slot: artworkSlot);
    if (bytes == null) {
      return FormSprite(form, size: size, semanticLabel: semanticLabel);
    }
    return Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
