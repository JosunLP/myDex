import 'package:mydex_application/mydex_application.dart';
import 'package:test/test.dart';

void main() {
  test('normalization', () {
    expect(normalizeSearchText('  Großbrand '), 'grossbrand');
    expect(normalizeSearchText('Nidoran♀'), 'nidoran f');
    expect(normalizeSearchText('Mr. Mime'), 'mr mime');
    expect(normalizeSearchText('Flabébé'), 'flabebe');
  });

  test('Levenshtein with early exit', () {
    expect(levenshtein('glurak', 'glurak'), 0);
    expect(levenshtein('glurk', 'glurak'), 1);
    expect(levenshtein('abc', 'xyz', max: 1), 2);
  });
}
