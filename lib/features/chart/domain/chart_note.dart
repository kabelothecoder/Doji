import '../../markets/domain/candle.dart';
import 'drawing.dart';

/// One line of the co-pilot exchange under a drawing.
class CopilotTurn {
  const CopilotTurn({required this.fromYou, required this.text, required this.at});

  final bool fromYou;
  final String text;
  final DateTime at;

  Map<String, Object?> toJson() => {'fromYou': fromYou, 'text': text, 'at': at.toUtc().toIso8601String()};

  static CopilotTurn? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    final text = json['text'];
    if (at == null || text is! String) return null;
    return CopilotTurn(fromYou: json['fromYou'] == true, text: text, at: at.toUtc());
  }
}

/// The trader's own answer to a checklist row.
enum CheckAnswer {
  yes('yes'),
  no('no'),
  unsure('not sure');

  const CheckAnswer(this.label);

  final String label;
}

/// One row of the pre-trade check as it stood when the trader answered.
class ChecklistAnswer {
  const ChecklistAnswer({required this.label, required this.status, this.answer});

  /// The condition or limit ("London session is open", "trades today 2 of 3").
  final String label;

  /// What doji measured: met | notMet | waiting | limitHit | ok.
  final String status;
  final CheckAnswer? answer;

  ChecklistAnswer withAnswer(CheckAnswer? a) => ChecklistAnswer(label: label, status: status, answer: a);

  Map<String, Object?> toJson() => {'label': label, 'status': status, 'answer': ?answer?.name};

  static ChecklistAnswer? fromJson(Object? json) {
    if (json is! Map) return null;
    final label = json['label'], status = json['status'];
    if (label is! String || status is! String) return null;
    return ChecklistAnswer(
      label: label,
      status: status,
      answer: CheckAnswer.values.asNameMap()[json['answer']],
    );
  }
}

/// Everything doji keeps about one mark on the chart: the drawing, the
/// trader's reason in their own words, the co-pilot exchange, the pre-trade
/// check (positions), and the trade it led to. Local first, like the journal.
class ChartNote {
  const ChartNote({
    required this.id,
    required this.accountId,
    required this.symbol,
    required this.timeframe,
    required this.createdAt,
    required this.updatedAt,
    required this.drawing,
    this.reason,
    this.copilot = const [],
    this.checklist,
    this.tradeId,
    this.deleted = false,
  });

  /// Same as the drawing's id.
  final String id;
  final String accountId;
  final String symbol;

  /// The timeframe it was drawn on (the drawing shows on every timeframe).
  final Timeframe timeframe;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Drawing drawing;

  /// Null = the trader skipped "what is this?".
  final String? reason;
  final List<CopilotTurn> copilot;
  final List<ChecklistAnswer>? checklist;
  final String? tradeId;

  /// Deleted from the chart. Kept (hidden) so undo can bring it back.
  final bool deleted;

  ChartNote copyWith({
    DateTime? updatedAt,
    Drawing? drawing,
    String? Function()? reason,
    List<CopilotTurn>? copilot,
    List<ChecklistAnswer>? Function()? checklist,
    String? Function()? tradeId,
    bool? deleted,
  }) => ChartNote(
    id: id,
    accountId: accountId,
    symbol: symbol,
    timeframe: timeframe,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    drawing: drawing ?? this.drawing,
    reason: reason == null ? this.reason : reason(),
    copilot: copilot ?? this.copilot,
    checklist: checklist == null ? this.checklist : checklist(),
    tradeId: tradeId == null ? this.tradeId : tradeId(),
    deleted: deleted ?? this.deleted,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'accountId': accountId,
    'symbol': symbol,
    'timeframe': timeframe.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'drawing': drawing.toJson(),
    'reason': ?reason,
    'copilot': [for (final t in copilot) t.toJson()],
    if (checklist != null) 'checklist': [for (final c in checklist!) c.toJson()],
    'tradeId': ?tradeId,
    if (deleted) 'deleted': true,
  };

  /// Null for a record that does not parse (skipped, never fatal).
  static ChartNote? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], accountId = json['accountId'], symbol = json['symbol'];
    final tf = Timeframe.values.asNameMap()[json['timeframe']];
    final created = DateTime.tryParse('${json['createdAt']}');
    final updated = DateTime.tryParse('${json['updatedAt']}');
    final drawing = Drawing.fromJson(json['drawing']);
    if (id is! String || accountId is! String || symbol is! String) return null;
    if (tf == null || created == null || updated == null || drawing == null) return null;
    final turns = json['copilot'], check = json['checklist'];
    final reason = json['reason'], tradeId = json['tradeId'];
    return ChartNote(
      id: id,
      accountId: accountId,
      symbol: symbol,
      timeframe: tf,
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
      drawing: drawing,
      reason: reason is String ? reason : null,
      copilot: turns is List ? [for (final t in turns) ?CopilotTurn.fromJson(t)] : const [],
      checklist: check is List ? [for (final c in check) ?ChecklistAnswer.fromJson(c)] : null,
      tradeId: tradeId is String ? tradeId : null,
      deleted: json['deleted'] == true,
    );
  }
}

/// How long before a trade opens a note on the same account and instrument
/// still counts as leading to it.
/// shortcut: a time window, not an explicit link; upgrade when a trade can be
/// logged straight from its position box.
const kNoteLinkWindow = Duration(hours: 24);

/// The notes that led to a trade opened at [openedAt]: same account and
/// symbol, made in the [kNoteLinkWindow] before it, not deleted, not linked yet.
Iterable<ChartNote> notesLeadingTo(
  Iterable<ChartNote> notes, {
  required String? accountId,
  required String symbol,
  required DateTime openedAt,
}) => notes.where(
  (n) =>
      !n.deleted &&
      n.tradeId == null &&
      n.accountId == accountId &&
      n.symbol.toUpperCase() == symbol.toUpperCase() &&
      !n.createdAt.isAfter(openedAt) &&
      openedAt.difference(n.createdAt) <= kNoteLinkWindow,
);
