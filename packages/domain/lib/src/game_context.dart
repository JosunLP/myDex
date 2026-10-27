import 'package:meta/meta.dart';

import 'game.dart';
import 'ids.dart';

/// Passed through every rule-dependent query (ADR 0004).
/// The language is deliberately not part of the context: it only affects output.
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

  /// Revision of the catalog pack this context comes from.
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
