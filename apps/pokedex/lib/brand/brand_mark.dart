import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/theme.dart';

/// Background of the app icon.
enum IconShape {
  /// Full-bleed square: the platform applies its own mask (iOS, Android).
  square,

  /// Rounded square with margin and shadow, on the macOS icon grid.
  rounded,

  /// Rounded square filling the canvas (Windows, Linux, legacy Android).
  tile,

  /// Circle (Android round icons).
  circle,
}

/// Paints the myDex mark: the Pokédex lens with three signal LEDs orbiting
/// it. The single source of the brand – the app, the splash screen and all
/// platform icons (`tool/brand`) are drawn by this painter.
///
/// The mark is designed in a unit square and stays inside its inscribed
/// circle, so it survives every icon mask (circle, squircle, teardrop).
class BrandPainter extends CustomPainter {
  const BrandPainter({
    this.background = false,
    this.shape = IconShape.square,
    this.markScale = 1,
    this.monochrome,
    this.leds = const [1, 1, 1],
    this.shine = 0,
    this.backgroundColors = const [
      Color(0xFFE5524A),
      DexColors.red,
      Color(0xFFA82A2B),
    ],
  });

  /// Whether to paint the red icon background.
  final bool background;
  final IconShape shape;

  /// Size of the mark relative to the canvas.
  final double markScale;

  /// Paints the mark in a single colour (Android themed icons).
  final Color? monochrome;

  /// Brightness of the red, yellow and green LED (0–1).
  final List<double> leds;

  /// Position of a light sweep across the lens glass (0 = none, 0–1 = sweep).
  final double shine;

  final List<Color> backgroundColors;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    if (background) _paintBackground(canvas, s);
    if (markScale > 0) {
      final inset = s * (1 - markScale) / 2;
      canvas.translate(inset, inset);
      _paintMark(canvas, s * markScale);
    }
    canvas.restore();
  }

  void _paintBackground(Canvas canvas, double s) {
    final RRect frame;
    if (shape == IconShape.rounded) {
      // macOS grid: 824/1024 body with a ~22 % corner radius.
      final body = s * 824 / 1024;
      final o = (s - body) / 2;
      frame = RRect.fromRectAndRadius(
        Rect.fromLTWH(o, o + s * 0.008, body, body),
        Radius.circular(body * 0.225),
      );
      canvas.drawRRect(
        frame.shift(Offset(0, s * 0.012)),
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.014),
      );
    } else if (shape == IconShape.tile) {
      final o = s * 0.03;
      frame = RRect.fromRectAndRadius(
        Rect.fromLTWH(o, o, s - 2 * o, s - 2 * o),
        Radius.circular(s * 0.22),
      );
    } else if (shape == IconShape.circle) {
      frame = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s),
        Radius.circular(s / 2),
      );
    } else {
      frame = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.zero);
    }
    final rect = frame.outerRect;
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: backgroundColors,
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // Soft light from the top left, like the glossy casing.
    canvas.save();
    canvas.clipRRect(frame);
    canvas.drawCircle(
      rect.topLeft + Offset(rect.width * 0.2, rect.height * 0.1),
      rect.width * 0.75,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center:
                    rect.topLeft + Offset(rect.width * 0.2, rect.height * 0.1),
                radius: rect.width * 0.75,
              ),
            ),
    );
    canvas.restore();
  }

  void _paintMark(Canvas canvas, double s) {
    final mono = monochrome;
    // Cut-outs of the monochrome variant must only affect the mark itself.
    if (mono != null) canvas.saveLayer(Rect.fromLTWH(0, 0, s, s), Paint());
    final center = Offset(s * 0.47, s * 0.54);
    final outer = s * 0.335;
    final glass = s * 0.262;

    // Lens rim with a soft drop shadow.
    if (mono == null) {
      canvas.drawCircle(
        center + Offset(0, s * 0.018),
        outer,
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
      );
    }
    canvas.drawCircle(
      center,
      outer,
      Paint()..color = mono ?? DexColors.lensRim,
    );
    if (mono == null) {
      // Thin dark bezel between rim and glass.
      canvas.drawCircle(
        center,
        glass + s * 0.018,
        Paint()..color = DexColors.hinge,
      );
    } else {
      canvas.drawCircle(
        center,
        glass + s * 0.03,
        Paint()..blendMode = BlendMode.clear,
      );
    }

    final glassRect = Rect.fromCircle(center: center, radius: glass);
    canvas.drawCircle(
      center,
      glass,
      Paint()
        ..color = mono ?? Colors.white
        ..shader = mono != null
            ? null
            : const RadialGradient(
                center: Alignment(-0.38, -0.42),
                radius: 1.05,
                colors: [
                  DexColors.lensLight,
                  DexColors.lens,
                  Color(0xFF1B4C83),
                ],
                stops: [0, 0.48, 1],
              ).createShader(glassRect),
    );

    // Specular highlight (cut out in the monochrome variant).
    final highlight = Paint()
      ..color = mono == null
          ? Colors.white.withValues(alpha: 0.85)
          : Colors.white
      ..blendMode = mono == null ? BlendMode.srcOver : BlendMode.clear;
    canvas.save();
    canvas.translate(center.dx - glass * 0.38, center.dy - glass * 0.4);
    canvas.rotate(-math.pi / 4.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: glass * 0.62,
        height: glass * 0.3,
      ),
      highlight,
    );
    canvas.restore();
    canvas.drawCircle(
      center + Offset(glass * 0.46, glass * 0.44),
      glass * 0.09,
      Paint()
        ..color = mono == null
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.white
        ..blendMode = mono == null ? BlendMode.srcOver : BlendMode.clear,
    );

    // Light sweep across the glass (splash animation).
    if (mono == null && shine > 0 && shine < 1) {
      canvas.save();
      canvas.clipPath(Path()..addOval(glassRect));
      final x = glassRect.left - glass + shine * glass * 4;
      canvas.drawRect(
        glassRect,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0),
                ],
                transform: const GradientRotation(-math.pi / 5),
              ).createShader(
                Rect.fromLTWH(
                  x - glass * 0.5,
                  glassRect.top,
                  glass,
                  glassRect.height,
                ),
              ),
      );
      canvas.restore();
    }

    // Three LEDs orbiting the lens towards the top right.
    const colors = [DexColors.ledRed, DexColors.ledYellow, DexColors.ledGreen];
    final orbit = outer + s * 0.1;
    final led = s * 0.062;
    for (var i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + 0.16 + i * 0.5;
      final c = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      if (mono != null) {
        canvas.drawCircle(c, led, Paint()..color = mono);
        continue;
      }
      final on = leds[i].clamp(0.0, 1.0);
      canvas.drawCircle(c, led + s * 0.014, Paint()..color = DexColors.lensRim);
      final lit = Color.lerp(
        Color.lerp(colors[i], DexColors.hinge, 0.55),
        colors[i],
        on,
      )!;
      if (on > 0) {
        canvas.drawCircle(
          c,
          led * (1.2 + on * 0.6),
          Paint()
            ..color = colors[i].withValues(alpha: 0.28 * on)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, led * 0.6),
        );
      }
      canvas.drawCircle(c, led, Paint()..color = lit);
      canvas.drawCircle(
        c + Offset(-led * 0.32, -led * 0.32),
        led * 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.35 * on),
      );
    }
    if (mono != null) canvas.restore();
  }

  @override
  bool shouldRepaint(BrandPainter old) =>
      old.background != background ||
      old.shape != shape ||
      old.markScale != markScale ||
      old.monochrome != monochrome ||
      old.shine != shine ||
      old.leds[0] != leds[0] ||
      old.leds[1] != leds[1] ||
      old.leds[2] != leds[2];
}

/// The myDex mark without background. Purely decorative.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: const BrandPainter()),
  );
}

/// The app icon as a widget (about page, empty states).
class AppIconArt extends StatelessWidget {
  const AppIconArt({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: CustomPaint(
        size: Size.square(size),
        painter: const BrandPainter(background: true, markScale: 0.8),
      ),
    ),
  );
}

/// Mark and word mark "myDex".
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: size * 0.82,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1,
      color: color ?? scheme.onSurface,
    );
    return Semantics(
      label: 'myDex',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: size * 1.15),
          SizedBox(width: size * 0.3),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'my', style: base),
                TextSpan(
                  text: 'Dex',
                  style: base.copyWith(color: color ?? scheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The mark "booting up": it scales in, the LEDs light up one after another
/// and a light sweeps across the lens. Loops while [running]; with reduced
/// motion it is shown static.
class AnimatedBrandMark extends StatefulWidget {
  const AnimatedBrandMark({super.key, this.size = 96, this.running = true});

  final double size;
  final bool running;

  @override
  State<AnimatedBrandMark> createState() => _AnimatedBrandMarkState();
}

class _AnimatedBrandMarkState extends State<AnimatedBrandMark>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AnimatedBrandMark old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.running && !Motion.reduced(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0.999;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        double led(int i) {
          final start = 0.12 + i * 0.14;
          return Curves.easeOut.transform(((t - start) / 0.12).clamp(0, 1));
        }

        final fade = t > 0.85 ? 1 - (t - 0.85) / 0.15 : 1.0;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: BrandPainter(
            leds: [led(0) * fade, led(1) * fade, led(2) * fade],
            shine: ((t - 0.5) / 0.4).clamp(0, 1),
          ),
        );
      },
    ),
  );
}
