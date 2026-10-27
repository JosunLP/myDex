import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Die blaue Linse mit den drei Signal-LEDs vom Pokédex-Gehäuse.
/// Rein dekorativ.
class PokedexLens extends StatelessWidget {
  const PokedexLens({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final led = size * 0.28;
    Widget dot(Color color) => Container(
      width: led,
      height: led,
      margin: EdgeInsets.only(left: size * 0.12),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: DexColors.hinge, width: 1),
      ),
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DexColors.lensRim,
              border: Border.all(color: DexColors.hinge, width: 1.5),
            ),
            padding: EdgeInsets.all(size * 0.12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.35),
                  radius: 0.9,
                  colors: [
                    Color.lerp(DexColors.lens, Colors.white, 0.6)!,
                    DexColors.lens,
                    Color.lerp(DexColors.lens, DexColors.hinge, 0.4)!,
                  ],
                ),
              ),
            ),
          ),
          dot(DexColors.ledRed),
          dot(DexColors.ledYellow),
          dot(DexColors.ledGreen),
        ],
      ),
    );
  }
}

/// Bildschirm des Pokédex: dunkler Rahmen, darin ein heller, nach dem Typ
/// eingefärbter Anzeigebereich.
class DexScreen extends StatelessWidget {
  const DexScreen({super.key, required this.tint, required this.child});

  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A2D2E) : const Color(0xFFF4F6F2);
    return Container(
      padding: const EdgeInsets.all(Space.s),
      decoration: BoxDecoration(
        color: DexColors.hinge,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(base, tint, dark ? 0.35 : 0.45)!, base],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Nationale Nummer im Stil einer kleinen Digitalanzeige.
class DexNumber extends StatelessWidget {
  const DexNumber(this.number, {super.key, this.dense = false});

  final int number;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: dense ? Space.xs + 2 : Space.s,
      vertical: dense ? 1 : 2,
    ),
    decoration: BoxDecoration(
      color: DexColors.hinge,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '#${number.toString().padLeft(4, '0')}',
      style: TextStyle(
        color: const Color(0xFF7CFC9A),
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier New', 'Courier'],
        fontSize: dense ? 12 : 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        fontFeatures: tabularFigures,
      ),
    ),
  );
}
