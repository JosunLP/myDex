// Generates all app icons and splash images from the brand painter.
//
//   cd apps/pokedex && flutter test tool/brand/generate_icons_test.dart
//
// Then run `python3 tool/brand/finalize_icons.py` (Windows .ico, opaque iOS
// icons).
// The output is committed; rerun after changing `lib/brand/brand_mark.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/theme.dart';
import 'package:mydex_app/brand/brand_mark.dart';

import 'brand_render.dart';

const _android = 'android/app/src/main/res';
const _ios = 'ios/Runner/Assets.xcassets';
const _macos = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';

/// Android density buckets and their scale factor.
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

void main() {
  test('Android launcher icons (legacy, round, adaptive, themed)', () async {
    for (final MapEntry(key: bucket, value: f) in _densities.entries) {
      final dir = '$_android/mipmap-$bucket';
      final legacy = (48 * f).round();
      await writePng(
        '$dir/ic_launcher.png',
        const BrandPainter(
          background: true,
          shape: IconShape.tile,
          markScale: 0.78,
        ),
        legacy,
      );
      await writePng(
        '$dir/ic_launcher_round.png',
        const BrandPainter(
          background: true,
          shape: IconShape.circle,
          markScale: 0.74,
        ),
        legacy,
      );
      // Adaptive icons: 108 dp layers, content within the 66 dp safe zone.
      final adaptive = (108 * f).round();
      await writePng(
        '$dir/ic_launcher_background.png',
        const _BackgroundOnly(),
        adaptive,
      );
      await writePng(
        '$dir/ic_launcher_foreground.png',
        const BrandPainter(markScale: 0.58),
        adaptive,
      );
      await writePng(
        '$dir/ic_launcher_monochrome.png',
        const BrandPainter(markScale: 0.58, monochrome: Colors.black),
        adaptive,
      );
      // Splash icon (Android 12+: 288 dp canvas, content within 192 dp).
      await writePng(
        '$_android/drawable-$bucket/splash_icon.png',
        const BrandPainter(markScale: 0.64),
        (288 * f).round(),
      );
    }
  });

  test('iOS app icons and launch image', () async {
    const sizes = {
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final MapEntry(key: name, value: px) in sizes.entries) {
      // App Store icons must be opaque: paint on the brand red.
      await writePng(
        '$_ios/AppIcon.appiconset/$name',
        const BrandPainter(background: true, markScale: 0.8),
        px,
        null,
        DexColors.red,
      );
    }
    for (final (suffix, f) in [('', 1), ('@2x', 2), ('@3x', 3)]) {
      await writePng(
        '$_ios/LaunchImage.imageset/LaunchImage$suffix.png',
        const BrandPainter(),
        128 * f,
      );
    }
  });

  test('macOS app icons', () async {
    for (final px in [16, 32, 64, 128, 256, 512, 1024]) {
      await writePng(
        '$_macos/app_icon_$px.png',
        const BrandPainter(
          background: true,
          shape: IconShape.rounded,
          markScale: 0.66,
        ),
        px,
      );
    }
  });

  test('Windows and Linux icons, brand assets', () async {
    const tile = BrandPainter(
      background: true,
      shape: IconShape.tile,
      markScale: 0.8,
    );
    for (final px in [16, 20, 24, 32, 40, 48, 64, 128, 256]) {
      await writePng('tool/brand/out/windows_$px.png', tile, px);
    }
    for (final px in [32, 48, 64, 128, 256, 512]) {
      await writePng(
        'linux/packaging/icons/hicolor/${px}x$px/apps/io.github.josunlp.mydex_app.png',
        tile,
        px,
      );
    }
    await writePng('linux/runner/resources/app_icon.png', tile, 256);
    await writePng('../../docs/brand/app-icon.png', tile, 512);
    await writePng('../../docs/brand/mark.png', const BrandPainter(), 512);
    await writePng(
      '../../docs/brand/mark-monochrome.png',
      const BrandPainter(monochrome: DexColors.hinge),
      512,
    );
  });
}

/// The red icon background without the mark (adaptive icon layer).
class _BackgroundOnly extends CustomPainter {
  const _BackgroundOnly();

  @override
  void paint(Canvas canvas, Size size) =>
      const BrandPainter(background: true, markScale: 0).paint(canvas, size);

  @override
  bool shouldRepaint(_BackgroundOnly old) => false;
}
