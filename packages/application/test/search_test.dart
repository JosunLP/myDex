import 'package:mydex_application/mydex_application.dart';
import 'package:test/test.dart';

void main() {
  test('Normalisierung', () {
    expect(normalizeSearchText('  Großbrand '), 'grossbrand');
    expect(normalizeSearchText('Nidoran♀'), 'nidoran f');
    expect(normalizeSearchText('Mr. Mime'), 'mr mime');
    expect(normalizeSearchText('Flabébé'), 'flabebe');
  });

  test('Levenshtein mit Abbruch', () {
    expect(levenshtein('glurak', 'glurak'), 0);
    expect(levenshtein('glurk', 'glurak'), 1);
    expect(levenshtein('abc', 'xyz', max: 1), 2);
  });
}
