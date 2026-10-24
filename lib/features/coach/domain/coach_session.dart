import 'coach.dart';

/// A coach session the trader chose to keep ("save" on the session screen).
class CoachSession {
  const CoachSession({
    required this.id,
    required this.startedAt,
    required this.voice,
    required this.turns,
    this.savedAt,
  });

  final String id;
  final DateTime startedAt;
  final CoachVoice voice;

  /// Oldest first, the coach's opener included.
  final List<CoachTurn> turns;
  final DateTime? savedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'voice': voice.value,
    'turns': [for (final t in turns) t.toJson()],
    if (savedAt != null) 'savedAt': savedAt!.toUtc().toIso8601String(),
  };

  /// Null when the record is not a session. Turns that fail to parse are
  /// dropped; the rest of the transcript stays.
  static CoachSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final startedAt = DateTime.tryParse('${json['startedAt']}');
    final turns = json['turns'];
    if (id is! String || startedAt == null || turns is! List) return null;
    return CoachSession(
      id: id,
      startedAt: startedAt,
      voice: CoachVoice.of('${json['voice']}'),
      turns: [for (final t in turns) ?CoachTurn.fromJson(t)],
      savedAt: DateTime.tryParse('${json['savedAt']}'),
    );
  }
}
