import 'package:meta/meta.dart';

/// Ergebnis einer Textauflösung, inkl. Hinweis, ob auf eine andere Sprache
/// ausgewichen wurde (fehlende Übersetzungen werden sichtbar gekennzeichnet).
@immutable
class ResolvedText {
  const ResolvedText(this.text, this.language, {required this.isFallback});

  final String text;
  final String language;
  final bool isFallback;
}

/// Mehrsprachiger Text. Schlüssel sind Sprachcodes (`de`, `en`, `ja-Hrkt` …).
@immutable
class LocalizedText {
  const LocalizedText(this.values);

  factory LocalizedText.fromJson(Map<String, Object?> json) =>
      LocalizedText({for (final e in json.entries) e.key: e.value! as String});

  final Map<String, String> values;

  static const fallbackLanguage = 'en';

  ResolvedText resolve(String language) {
    final exact = values[language];
    if (exact != null) return ResolvedText(exact, language, isFallback: false);
    final base = language.split(RegExp('[-_]')).first;
    final byBase = values[base];
    if (byBase != null) return ResolvedText(byBase, base, isFallback: false);
    final fallback = values[fallbackLanguage];
    if (fallback != null) {
      return ResolvedText(fallback, fallbackLanguage, isFallback: true);
    }
    if (values.isEmpty) return const ResolvedText('?', '', isFallback: true);
    final first = values.entries.first;
    return ResolvedText(first.value, first.key, isFallback: true);
  }

  String call(String language) => resolve(language).text;

  Iterable<String> get allValues => values.values;

  Map<String, Object?> toJson() => values;
}
