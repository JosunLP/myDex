import 'package:meta/meta.dart';

import 'game.dart';
import 'ids.dart';

/// Wird durch jede regelabhängige Abfrage gereicht (ADR 0004).
/// Die Sprache ist bewusst nicht Teil des Kontexts: sie betrifft nur die Ausgabe.
@immutable
class GameContext {
  const GameContext({
    required this.version,
    required this.versionGroup,
    required this.ruleset,
    required this.contentRevision,
  });

  final GameVersion version;
  final VersionGroup versionGroup;
  final Ruleset ruleset;

  /// Revision des Katalogpakets, aus dem dieser Kontext stammt.
  final String contentRevision;

  GameVersionId get versionId => version.id;
  VersionGroupId get versionGroupId => versionGroup.id;
  int get generation => versionGroup.generation;

  @override
  bool operator ==(Object other) =>
      other is GameContext &&
      other.version.id == version.id &&
      other.contentRevision == contentRevision;

  @override
  int get hashCode => Object.hash(version.id, contentRevision);
}
