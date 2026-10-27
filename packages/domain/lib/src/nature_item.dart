import 'package:meta/meta.dart';

import 'ids.dart';
import 'localized_text.dart';
import 'stats.dart';

/// Nature: raises one stat by 10 %, lowers another (neutral: none).
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

/// Bag pockets whose items a Pokémon cannot hold.
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

  /// Bag pocket in the source (e.g. `battle`, `berries`, `key`).
  final String? pocket;

  /// Generations in which the item exists according to the source.
  final Set<int> generations;

  /// Can be held in this generation (as far as the data goes).
  bool holdableIn(int generation) =>
      generations.contains(generation) &&
      pocket != null &&
      !nonHoldablePockets.contains(pocket);
}
