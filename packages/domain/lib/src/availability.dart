/// Spielabhängige Aussagen sind nie nur „ja/nein“ (ADR 0005).
enum DataAvailability {
  confirmedAvailable('confirmed_available'),
  confirmedUnavailable('confirmed_unavailable'),
  notApplicable('not_applicable'),
  unknown('unknown'),
  notResearched('not_researched');

  const DataAvailability(this.key);

  final String key;

  /// Nur bestätigte Aussagen dürfen als Fakt dargestellt werden.
  bool get isConfirmed =>
      this == confirmedAvailable ||
      this == confirmedUnavailable ||
      this == notApplicable;

  /// Datenlücke: muss in der UI als solche gekennzeichnet werden.
  bool get isGap => !isConfirmed;

  static DataAvailability parse(String key) =>
      DataAvailability.values.firstWhere(
        (a) => a.key == key,
        orElse: () =>
            throw FormatException('Unbekannter Verfügbarkeitszustand: $key'),
      );
}
