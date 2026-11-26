// Generates the GitHub social preview (1280 × 640) from the brand painter.
//
//   cd apps/pokedex && flutter test tool/brand/social_preview_test.dart
//
// Output: docs/brand/social-preview.png. Upload it in the repository
// settings (Settings → General → Social preview). No Pokémon artwork: only
// the myDex mark, word mark and type.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/theme.dart';
import 'package:mydex_app/brand/brand_mark.dart';

const _size = Size(1280, 640);
const _output = '../../docs/brand/social-preview.png';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  testWidgets('GitHub social preview', (tester) async {
    await tester.runAsync(() async {
      await _loadFont(AppFonts.sans, [
        for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
          'assets/fonts/PlusJakartaSans-$w.ttf',
      ]);
      await _loadFont(AppFonts.mono, ['assets/fonts/JetBrainsMono-Bold.ttf']);
    });
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.dark),
        home: RepaintBoundary(
          key: key,
          // Material provides the text defaults (no debug underlines).
          child: const Material(
            type: MaterialType.transparency,
            child: _Preview(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      expect(image.width, 1280);
      expect(image.height, 640);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File(_output)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}

class _Preview extends StatelessWidget {
  const _Preview();

  static const _ink = Color(0xFFF7F0EF);
  static const _muted = Color(0xFFC9BEBD);

  @override
  Widget build(BuildContext context) {
    const sans = TextStyle(fontFamily: AppFonts.sans, color: _ink, height: 1);
    return SizedBox.fromSize(
      size: _size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF26201F), DexColors.hinge, Color(0xFF110E0F)],
          ),
        ),
        child: CustomPaint(
          painter: const _Backdrop(),
          child: Padding(
            // Inside GitHub's recommended 40 px border, with room to spare.
            padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 80),
            child: Row(
              children: [
                const _Icon(size: 300),
                const SizedBox(width: 72),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'my'),
                            TextSpan(
                              text: 'Dex',
                              style: sans.copyWith(
                                color: const Color(0xFFFF6A5F),
                              ),
                            ),
                          ],
                        ),
                        style: sans.copyWith(
                          fontSize: 132,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Your offline Pokédex for every game',
                        style: sans.copyWith(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Pill('International Pokédex', accent: true),
                          _Pill('Every game, exact data'),
                          _Pill('Offline-first'),
                          _Pill('Optional sync'),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'ANDROID · iOS · WINDOWS · macOS · LINUX',
                        style: sans.copyWith(
                          fontFamily: AppFonts.mono,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app icon with a soft red glow.
class _Icon extends StatelessWidget {
  const _Icon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.24),
      boxShadow: [
        BoxShadow(
          color: DexColors.red.withValues(alpha: 0.45),
          blurRadius: 90,
          spreadRadius: 6,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 30,
          offset: const Offset(0, 16),
        ),
      ],
    ),
    child: AppIconArt(size: size),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
    decoration: BoxDecoration(
      color: accent ? DexColors.red : Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: accent
            ? const Color(0xFFE5524A)
            : Colors.white.withValues(alpha: 0.16),
      ),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1,
        color: _Preview._ink,
      ),
    ),
  );
}

/// The lens rings of the app's tinted surfaces, large and faint, plus the
/// three signal LEDs in the corner.
class _Backdrop extends CustomPainter {
  const _Backdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.86, size.height * 0.18);
    final r = size.height * 0.72;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = DexColors.red.withValues(alpha: 0.16)
      ..strokeWidth = r * 0.16;
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(
      c,
      r * 0.45,
      ring
        ..strokeWidth = r * 0.06
        ..color = DexColors.red.withValues(alpha: 0.12),
    );
    // A thin red edge at the bottom: the casing.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 10, size.width, 10),
      Paint()
        ..shader = const LinearGradient(
          colors: [DexColors.redDark, DexColors.red, Color(0xFFE5524A)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 10)),
    );
    for (final (i, color) in [
      DexColors.ledRed,
      DexColors.ledYellow,
      DexColors.ledGreen,
    ].indexed) {
      final center = Offset(size.width - 96 - (2 - i) * 34, size.height - 56);
      canvas.drawCircle(
        center,
        13,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(center, 9, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_Backdrop old) => false;
}
