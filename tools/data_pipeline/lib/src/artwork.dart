import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Size of the artworks in the media pack (edge length in pixels).
const artworkSize = 256;

/// Version of the downscaling process; part of the cache path so that a
/// change does not reuse old results.
const artworkProcess = 'a256-v1';

/// Downscales an official artwork and stores it as a PNG with a 256-colour
/// palette without losing transparency:
/// - 224 entries for opaque colours (octree over RGB),
/// - 31 entries for semi-transparent edges (the average colour per opacity
///   level; edges are almost always outlines),
/// - 1 fully transparent entry.
/// About 17 KB instead of 120 KB per image, visually hard to tell apart.
/// Deterministic: the same input gives the same bytes.
Uint8List shrinkArtwork(List<int> png) {
  final decoded = img.decodePng(Uint8List.fromList(png));
  if (decoded == null) throw const FormatException('Not a readable PNG');
  return _palettePng(
    img.copyResize(
      decoded.convert(numChannels: 4),
      width: artworkSize,
      height: artworkSize,
      interpolation: img.Interpolation.average,
    ),
  );
}

/// Largest edge length of the in-game images from Gen 7 (still or icon).
const stillSize = 96;

/// Version of the still image process (part of the cache path and revision).
const stillProcess = 's96-v1';

/// Still image from an in-game image from Gen 7 (animated GIF/WebP or icon):
/// first frame, transparent border trimmed, scaled down to at most
/// [stillSize] px (never up), palette PNG like the artwork. Deterministic.
Uint8List shrinkStill(List<int> bytes) {
  // Decode only the first frame: faster, and some animations in the source
  // are broken in later frames.
  final data = Uint8List.fromList(bytes);
  final decoder = img.findDecoderForData(data);
  if (decoder == null || decoder.startDecode(data) == null) {
    throw const FormatException('Not a readable image');
  }
  final first = decoder.decodeFrame(0);
  if (first == null) throw const FormatException('Not a readable image');
  var src = img.trim(
    first.convert(numChannels: 4),
    mode: img.TrimMode.transparent,
  );
  final longest = src.width > src.height ? src.width : src.height;
  if (longest > stillSize) {
    src = img.copyResize(
      src,
      width: src.width * stillSize ~/ longest,
      height: src.height * stillSize ~/ longest,
      interpolation: img.Interpolation.average,
    );
  }
  return _palettePng(src);
}

/// PNG with a 256-colour palette including semi-transparent edges (see above).
Uint8List _palettePng(img.Image src) {
  final w = src.width, h = src.height;

  final rgb = img.Image(width: w, height: h);
  for (final p in src) {
    rgb.setPixelRgb(p.x, p.y, p.r, p.g, p.b);
  }
  final q = img.quantize(
    rgb,
    numberOfColors: 224,
    method: img.QuantizeMethod.octree,
    dither: img.DitherKernel.none,
  );

  final out = img.Image(
    width: w,
    height: h,
    numChannels: 1,
    palette: img.PaletteUint8(256, 4),
  );
  final palette = out.palette!;
  final qp = q.palette!;
  for (var i = 0; i < 224; i++) {
    if (i < qp.numColors) {
      palette.setRgba(i, qp.getRed(i), qp.getGreen(i), qp.getBlue(i), 255);
    } else {
      palette.setRgba(i, 0, 0, 0, 255);
    }
  }
  final sums = List.generate(31, (_) => [0, 0, 0, 0]);
  for (final p in src) {
    final a = p.a.toInt();
    if (a >= 8 && a < 248) {
      final s = sums[(a * 31) >> 8];
      s[0] += p.r.toInt();
      s[1] += p.g.toInt();
      s[2] += p.b.toInt();
      s[3]++;
    }
  }
  for (var b = 0; b < 31; b++) {
    final n = sums[b][3] == 0 ? 1 : sums[b][3];
    palette.setRgba(
      224 + b,
      sums[b][0] ~/ n,
      sums[b][1] ~/ n,
      sums[b][2] ~/ n,
      ((b * 256 + 128) ~/ 31).clamp(0, 255),
    );
  }
  palette.setRgba(255, 0, 0, 0, 0);
  for (final p in src) {
    final a = p.a.toInt();
    final index = a < 8
        ? 255
        : a < 248
        ? 224 + ((a * 31) >> 8)
        : q.getPixel(p.x, p.y).index.toInt();
    out.setPixelIndex(p.x, p.y, index);
  }
  return img.encodePng(out, level: 9);
}

/// Version of the colour derivation (part of the media revision).
const artworkColorProcess = 'c1';

/// Main colour of an artwork as `0xRRGGBB` – for the background of the
/// Pokédex screen.
///
/// Only opaque pixels without outlines and highlights (very dark or very
/// bright) are counted. The pixels are sorted into colour cubes (8 levels per
/// channel) and weighted by chroma so that the body colour is not drowned out
/// by bright or grey areas. The result is the average colour of the heaviest
/// cube. Deterministic.
int artworkColor(List<int> png) {
  final decoded = img.decodePng(Uint8List.fromList(png));
  if (decoded == null) throw const FormatException('Not a readable PNG');
  final image = decoded.convert(numChannels: 4);
  final weight = <int, double>{};
  final sums = <int, List<int>>{};
  final all = [0, 0, 0, 0];
  void add(List<int> sum, int r, int g, int b) {
    sum[0] += r;
    sum[1] += g;
    sum[2] += b;
    sum[3]++;
  }

  for (final p in image) {
    if (p.a < 200) continue;
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    add(all, r, g, b);
    final hi = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final lo = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final l = (hi + lo) / 510;
    if (l < 0.16 || l > 0.92) continue;
    final chroma = (hi - lo) / 255;
    final key = (r >> 5) << 6 | (g >> 5) << 3 | (b >> 5);
    weight[key] = (weight[key] ?? 0) + 1 + 8 * chroma;
    add(sums.putIfAbsent(key, () => [0, 0, 0, 0]), r, g, b);
  }
  List<int> pick;
  if (weight.isEmpty) {
    if (all[3] == 0) return 0x808080;
    pick = all;
  } else {
    // On a tie the smaller key wins (deterministic).
    final best = (weight.keys.toList()..sort()).reduce(
      (a, b) => weight[b]! > weight[a]! ? b : a,
    );
    pick = sums[best]!;
  }
  final n = pick[3];
  return (pick[0] ~/ n) << 16 | (pick[1] ~/ n) << 8 | (pick[2] ~/ n);
}
