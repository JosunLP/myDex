import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Größe der Artworks im Medienpaket (Kantenlänge in Pixeln).
const artworkSize = 256;

/// Version des Verkleinerungsverfahrens; Teil des Cache-Pfads, damit eine
/// Änderung alte Ergebnisse nicht wiederverwendet.
const artworkProcess = 'a256-v1';

/// Verkleinert ein offizielles Artwork und speichert es als PNG mit
/// 256-Farben-Palette, ohne die Transparenz zu verlieren:
/// - 224 Einträge für deckende Farben (Octree über RGB),
/// - 31 Einträge für halbtransparente Kanten (je Deckkraftstufe die
///   Durchschnittsfarbe; Kanten sind fast immer Konturen),
/// - 1 Eintrag voll transparent.
/// Etwa 17 KB statt 120 KB je Bild, optisch kaum vom Original zu unterscheiden.
/// Deterministisch: gleiche Eingabe ergibt gleiche Bytes.
Uint8List shrinkArtwork(List<int> png) {
  final decoded = img.decodePng(Uint8List.fromList(png));
  if (decoded == null) throw const FormatException('Kein lesbares PNG');
  final src = img.copyResize(
    decoded.convert(numChannels: 4),
    width: artworkSize,
    height: artworkSize,
    interpolation: img.Interpolation.average,
  );
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

/// Version der Farbableitung (Teil der Medien-Revision).
const artworkColorProcess = 'c1';

/// Hauptfarbe eines Artworks als `0xRRGGBB` – für den Hintergrund der
/// Pokédex-Anzeige.
///
/// Gezählt werden nur deckende Pixel ohne Konturen und Glanzlichter (sehr
/// dunkel oder sehr hell). Die Pixel werden in Farbwürfel (je Kanal 8 Stufen)
/// einsortiert und nach Farbintensität (Chroma) gewichtet, damit die
/// Körperfarbe gegen helle oder graue Flächen nicht untergeht. Ergebnis ist
/// die Durchschnittsfarbe des schwersten Würfels. Deterministisch.
int artworkColor(List<int> png) {
  final decoded = img.decodePng(Uint8List.fromList(png));
  if (decoded == null) throw const FormatException('Kein lesbares PNG');
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
    // Bei Gleichstand entscheidet der kleinere Schlüssel (deterministisch).
    final best = (weight.keys.toList()..sort()).reduce(
      (a, b) => weight[b]! > weight[a]! ? b : a,
    );
    pick = sums[best]!;
  }
  final n = pick[3];
  return (pick[0] ~/ n) << 16 | (pick[1] ~/ n) << 8 | (pick[2] ~/ n);
}
