import 'package:meta/meta.dart';

import 'ids.dart';
import 'stats.dart';

/// A team member. Which fields make sense is decided by the ruleset.
@immutable
class TeamMember {
  const TeamMember({
    required this.form,
    this.nickname,
    this.level = 50,
    this.ability,
    this.item,
    this.nature,
    this.moves = const [],
    this.ivs = const {},
    this.evs = const {},
    this.shiny = false,
  });

  factory TeamMember.fromJson(Map<String, Object?> j) => TeamMember(
    form: FormId(j['form']! as String),
    nickname: j['nickname'] as String?,
    level: (j['level'] as int?) ?? 50,
    ability: j['ability'] == null ? null : AbilityId(j['ability']! as String),
    item: j['item'] == null ? null : ItemId(j['item']! as String),
    nature: j['nature'] == null ? null : NatureId(j['nature']! as String),
    moves: [
      for (final m in (j['moves'] as List<Object?>?) ?? const <Object?>[])
        MoveId(m! as String),
    ],
    ivs: _stats(j['ivs']),
    evs: _stats(j['evs']),
    shiny: (j['shiny'] as bool?) ?? false,
  );

  static Map<Stat, int> _stats(Object? json) => {
    for (final e in ((json as Map<String, Object?>?) ?? const {}).entries)
      Stat.values.byName(e.key): e.value! as int,
  };

  final FormId form;
  final String? nickname;
  final int level;
  final AbilityId? ability;
  final ItemId? item;
  final NatureId? nature;

  /// At most four moves.
  final List<MoveId> moves;

  /// Missing values count as the maximum (from Gen 3: 31; Gen 1–2: 15).
  final Map<Stat, int> ivs;

  /// Missing values count as 0.
  final Map<Stat, int> evs;
  final bool shiny;

  static const _unset = Object();

  TeamMember copyWith({
    FormId? form,
    Object? nickname = _unset,
    int? level,
    Object? ability = _unset,
    Object? item = _unset,
    Object? nature = _unset,
    List<MoveId>? moves,
    Map<Stat, int>? ivs,
    Map<Stat, int>? evs,
    bool? shiny,
  }) => TeamMember(
    form: form ?? this.form,
    nickname: identical(nickname, _unset) ? this.nickname : nickname as String?,
    level: level ?? this.level,
    ability: identical(ability, _unset) ? this.ability : ability as AbilityId?,
    item: identical(item, _unset) ? this.item : item as ItemId?,
    nature: identical(nature, _unset) ? this.nature : nature as NatureId?,
    moves: moves ?? this.moves,
    ivs: ivs ?? this.ivs,
    evs: evs ?? this.evs,
    shiny: shiny ?? this.shiny,
  );

  Map<String, Object?> toJson() => {
    'form': form.value,
    'nickname': ?nickname,
    'level': level,
    'ability': ?ability?.value,
    'item': ?item?.value,
    'nature': ?nature?.value,
    'moves': [for (final m in moves) m.value],
    if (ivs.isNotEmpty)
      'ivs': {for (final e in ivs.entries) e.key.name: e.value},
    if (evs.isNotEmpty)
      'evs': {for (final e in evs.entries) e.key.name: e.value},
    if (shiny) 'shiny': true,
  };
}

/// A team belongs to exactly one game (and thus one ruleset).
@immutable
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.version,
    this.members = const [],
    this.notes = '',
    required this.updatedAt,
  });

  factory Team.fromJson(Map<String, Object?> j) => Team(
    id: j['id']! as String,
    name: j['name']! as String,
    version: GameVersionId(j['version']! as String),
    members: [
      for (final m in (j['members'] as List<Object?>?) ?? const <Object?>[])
        TeamMember.fromJson(m! as Map<String, Object?>),
    ],
    notes: (j['notes'] as String?) ?? '',
    updatedAt: DateTime.parse(j['updatedAt']! as String),
  );

  final String id;
  final String name;
  final GameVersionId version;
  final List<TeamMember> members;
  final String notes;
  final DateTime updatedAt;

  Team copyWith({
    String? name,
    List<TeamMember>? members,
    String? notes,
    required DateTime updatedAt,
  }) => Team(
    id: id,
    name: name ?? this.name,
    version: version,
    members: members ?? this.members,
    notes: notes ?? this.notes,
    updatedAt: updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'version': version.value,
    'members': [for (final m in members) m.toJson()],
    if (notes.isNotEmpty) 'notes': notes,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
