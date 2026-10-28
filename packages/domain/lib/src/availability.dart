/// Game-dependent statements are never just "yes/no" (ADR 0005).
enum DataAvailability {
  confirmedAvailable('confirmed_available'),
  confirmedUnavailable('confirmed_unavailable'),
  notApplicable('not_applicable'),
  unknown('unknown'),
  notResearched('not_researched');

  const DataAvailability(this.key);

  final String key;

  /// Only confirmed statements may be presented as facts.
  bool get isConfirmed =>
      this == confirmedAvailable ||
      this == confirmedUnavailable ||
      this == notApplicable;

  /// Data gap: must be marked as such in the UI.
  bool get isGap => !isConfirmed;

  static DataAvailability parse(String key) =>
      DataAvailability.values.firstWhere(
        (a) => a.key == key,
        orElse: () => throw FormatException('Unknown availability state: $key'),
      );
}
