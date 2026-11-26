import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import 'form_sprite.dart';

/// Main colour of a form's artwork (from the media pack), otherwise `null`.
Color? artworkTint(WidgetRef ref, FormId form) =>
    switch (ref.watch(mediaProvider).value?.artworkColor(form)) {
      final int rgb => Color(0xFF000000 | rgb),
      null => null,
    };

/// Colour of a Pokémon: its artwork, otherwise its first type, otherwise
/// the brand colour.
Color pokemonTint(
  WidgetRef ref,
  FormId form,
  List<PokemonType> types,
  ColorScheme scheme,
) =>
    artworkTint(ref, form) ??
    (types.isEmpty ? scheme.primary : typeColor(types.first));

/// Hero tag shared by list thumbnails and the detail artwork, so the image
/// flies from the list into the detail page.
Object pokemonHeroTag(FormId form) => 'pokemon-art:${form.value}';

/// Thumbnail in lists: the in-game image on a small screen in the Pokémon's
/// colour – like the large Pokédex screen. Purely decorative.
class DexThumb extends ConsumerWidget {
  const DexThumb(
    this.form, {
    super.key,
    this.size = 48,
    this.shiny = false,
    this.version,
    this.hero = false,
  });

  final FormId form;
  final double size;
  final bool shiny;
  final GameVersionId? version;

  /// Takes part in the hero flight into the detail page.
  final bool hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = artworkTint(ref, form);
    final base = scheme.surfaceContainerHighest;
    Widget sprite = FormSprite(
      form,
      size: size,
      shiny: shiny,
      version: version,
    );
    if (hero) sprite = Hero(tag: pokemonHeroTag(form), child: sprite);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(base, tint, dark ? 0.45 : 0.42)!,
                  Color.lerp(base, tint, dark ? 0.25 : 0.2)!,
                ],
              ),
        color: tint == null ? base : null,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: sprite,
    );
  }
}

/// National number in the style of a small digital display.
class DexNumber extends StatelessWidget {
  const DexNumber(this.number, {super.key, this.dense = false});

  final int number;
  final bool dense;

  static String format(int number) => '#${number.toString().padLeft(4, '0')}';

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: dense ? Space.xs + 2 : Space.s,
      vertical: dense ? 1 : 3,
    ),
    decoration: BoxDecoration(
      color: DexColors.hinge,
      borderRadius: BorderRadius.circular(dense ? 6 : 8),
    ),
    child: Text(
      format(number),
      style: TextStyle(
        color: DexColors.display,
        fontFamily: AppFonts.mono,
        fontFamilyFallback: const ['monospace', 'Courier New'],
        fontSize: dense ? 11.5 : 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        height: 1.25,
        fontFeatures: tabularFigures,
      ),
    ),
  );
}

/// Soft, artwork-coloured backdrop for headers and cards: a gradient with a
/// large, faint lens ring – the Pokédex screen, reduced to its essence.
class TintBackdrop extends StatelessWidget {
  const TintBackdrop({
    super.key,
    required this.tint,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.strength = 1,
  });

  final Color tint;
  final Widget child;
  final BorderRadius borderRadius;

  /// 0–1: how strongly the tint shows.
  final double strength;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = scheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, tint, (dark ? 0.42 : 0.5) * strength)!,
            Color.lerp(base, tint, (dark ? 0.18 : 0.16) * strength)!,
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CustomPaint(
          painter: _RingPainter(
            Color.lerp(
              tint,
              dark ? Colors.white : Colors.white,
              0.5,
            )!.withValues(alpha: (dark ? 0.08 : 0.28) * strength),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.62;
    final c = Offset(size.width * 0.82, size.height * 0.34);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16;
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c, r * 0.45, paint..strokeWidth = r * 0.06);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
