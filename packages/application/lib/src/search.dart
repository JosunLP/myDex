import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'catalog_snapshot.dart';

/// Normalizes search text across languages.
String normalizeSearchText(String input) {
  var s = input.toLowerCase().trim();
  const map = {
    'ä': 'a',
    'ö': 'o',
    'ü': 'u',
    'ß': 'ss',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'à': 'a',
    'â': 'a',
    'á': 'a',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ç': 'c',
    'ñ': 'n',
    '♀': ' f',
    '♂': ' m',
    '’': '',
    "'": '',
    '.': '',
    ':': '',
  };
  final b = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    b.write(map[ch] ?? ch);
  }
  s = b.toString().replaceAll(RegExp(r'[\s\-_]+'), ' ').trim();
  return s;
}

enum MatchKind { exactNumber, exactName, exactAlias, prefix, contains, fuzzy }

@immutable
class SearchHit {
  const SearchHit(this.form, this.kind, this.matched);

  final FormId form;
  final MatchKind kind;

  /// The normalized term that matched.
  final String matched;
}

class _Term {
  _Term(this.text, {required this.isAlias});
  final String text;
  final bool isAlias;
}

/// Local in-memory search index. With the SQLite catalog, FTS5 handles the
/// full-text part; ranking and normalization stay defined here.
class PokemonSearchIndex {
  PokemonSearchIndex(CatalogSnapshot catalog) {
    for (final form in catalog.forms.values) {
      final species = catalog.species[form.speciesId]!;
      final terms = <_Term>[
        for (final n in catalog.displayName(form).allValues)
          _Term(normalizeSearchText(n), isAlias: false),
        if (form.name != null)
          for (final n in species.name.allValues)
            _Term(normalizeSearchText(n), isAlias: true),
        for (final a in [...species.aliases, ...form.aliases])
          _Term(normalizeSearchText(a), isAlias: true),
      ];
      _entries.add((form, species.nationalNumber, terms));
    }
  }

  final _entries = <(PokemonForm, int, List<_Term>)>[];

  /// Results, sorted by match kind, then number, default form first.
  List<SearchHit> search(String query, {int limit = 50}) {
    final q = normalizeSearchText(query.replaceFirst(RegExp(r'^#'), ''));
    if (q.isEmpty) return const [];
    final number = int.tryParse(q);
    final scored = <(SearchHit, int, bool)>[];
    for (final (form, national, terms) in _entries) {
      SearchHit? best;
      if (number != null && number == national) {
        best = SearchHit(form.id, MatchKind.exactNumber, q);
      } else {
        for (final t in terms) {
          final kind = _match(q, t);
          if (kind != null && (best == null || kind.index < best.kind.index)) {
            best = SearchHit(form.id, kind, t.text);
          }
        }
      }
      if (best != null) scored.add((best, national, form.isDefault));
    }
    scored.sort((a, b) {
      final k = a.$1.kind.index.compareTo(b.$1.kind.index);
      if (k != 0) return k;
      final n = a.$2.compareTo(b.$2);
      if (n != 0) return n;
      return (b.$3 ? 1 : 0).compareTo(a.$3 ? 1 : 0);
    });
    return [for (final s in scored.take(limit)) s.$1];
  }

  static MatchKind? _match(String q, _Term t) {
    if (t.text == q) {
      return t.isAlias ? MatchKind.exactAlias : MatchKind.exactName;
    }
    if (t.text.startsWith(q)) return MatchKind.prefix;
    if (q.length >= 3 && t.text.contains(q)) return MatchKind.contains;
    final allowed = q.length >= 8 ? 2 : (q.length >= 4 ? 1 : 0);
    if (allowed > 0 && (t.text.length - q.length).abs() <= allowed) {
      if (levenshtein(q, t.text, max: allowed) <= allowed) {
        return MatchKind.fuzzy;
      }
    }
    return null;
  }
}

/// Levenshtein distance with early exit above [max].
int levenshtein(String a, String b, {int max = 1 << 30}) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
      rowMin = math.min(rowMin, cur[j]);
    }
    if (rowMin > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}
