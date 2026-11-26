import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:mydex_app/brand/brand_mark.dart';

/// Renders [painter] into a PNG of [width] × [height] pixels.
Future<Uint8List> renderPng(
  CustomPainter painter,
  int width, [
  int? height,
  ui.Color? fill,
]) async {
  final h = height ?? width;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (fill != null) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), h.toDouble()),
      ui.Paint()..color = fill,
    );
  }
  painter.paint(canvas, ui.Size(width.toDouble(), h.toDouble()));
  final image = await recorder.endRecording().toImage(width, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<void> writePng(
  String path,
  CustomPainter painter,
  int width, [
  int? height,
  ui.Color? fill,
]) async {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(await renderPng(painter, width, height, fill));
}

/// Keeps the import of the brand library visible to the analyzer.
typedef Brand = BrandPainter;
