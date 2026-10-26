import 'package:meta/meta.dart';

import 'ids.dart';
import 'localized_text.dart';
import 'stats.dart';

/// Wesen: erhöht einen Wert um 10 %, senkt einen anderen (neutral: keiner).
@immutable
class Nature {
  const Nature({
    required this.id,
    required this.name,
    this.increased,
    this.decreased,
  });

  final NatureId id;
  final LocalizedText name;
  final Stat? increased;
  final Stat? decreased;

  bool get isNeutral => increased == null;
}

/// Taschenfächer, deren Items ein Pokémon nicht tragen kann.
const nonHoldablePockets = {'key', 'machines'};

@immutable
class ItemInfo {
  const ItemInfo({
    required this.id,
    required this.name,
    this.pocket,
    this.generations = const {},
  });

  final ItemId id;
  final LocalizedText name;

  /// Taschenfach der Quelle (z. B. `battle`, `berries`, `key`).
  final String? pocket;

  /// Generationen, in denen das Item laut Quelle existiert.
  final Set<int> generations;

  /// Kann in dieser Generation getragen werden (soweit die Daten reichen).
  bool holdableIn(int generation) =>
      generations.contains(generation) &&
      pocket != null &&
      !nonHoldablePockets.contains(pocket);
}
