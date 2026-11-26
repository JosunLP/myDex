import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/theme.dart';
import 'package:mydex_domain/mydex_domain.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('type badge text reaches 4.5:1 on the whole gradient', () {
    for (final type in PokemonType.values) {
      final color = typeColor(type);
      final text = onTypeColor(color);
      for (final background in [color, typeHighlight(color)]) {
        expect(
          _contrast(text, background),
          greaterThanOrEqualTo(4.5),
          reason: type.name,
        );
      }
    }
  });
}
