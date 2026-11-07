import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/domain/coach.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../markets/data/routed_market_data.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/domain/pair_brief.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../data/chart_note_repository.dart';
import '../data/copilot_service.dart';
import '../domain/bar_source.dart';
import '../domain/chart_note.dart';
import '../domain/chart_viewport.dart';
import '../domain/copilot.dart';
import '../domain/drawing.dart';
import '../domain/drawing_editor.dart';

/// The toolbar's tools. [key] is the Windows shortcut.
enum ChartTool {
  select('select', 'V', null),
  zone('zone', 'R', DrawingKind.zone),
  level('level', 'H', DrawingKind.level),
  trendLine('trend line', 'T', DrawingKind.trendLine),
  position('position', 'P', DrawingKind.position);

  const ChartTool(this.label, this.key, this.kind);

  final String label;
  final String key;
  final DrawingKind? kind;

  static ChartTool? forKey(LogicalKeyboardKey k) =>
      values.where((t) => t.key.toLowerCase() == k.keyLabel.toLowerCase()).firstOrNull;
}

class ChartState {
  const ChartState({
    required this.timeframe,
    this.tool = ChartTool.select,
    this.editor = const DrawingEditor(),
    this.selectedId,
    this.viewport,
  });

  final Timeframe timeframe;
  final ChartTool tool;
  final DrawingEditor editor;
  final String? selectedId;

  /// Null until the bars load (then the latest bars).
  final ChartViewport? viewport;

  List<Drawing> get drawings => editor.drawings;
  Drawing? get selected => selectedId == null ? null : editor.byId(selectedId!);

  ChartState copyWith({
    Timeframe? timeframe,
    ChartTool? tool,
    DrawingEditor? editor,
    String? Function()? selectedId,
    ChartViewport? Function()? viewport,
  }) => ChartState(
    timeframe: timeframe ?? this.timeframe,
    tool: tool ?? this.tool,
    editor: editor ?? this.editor,
    selectedId: selectedId == null ? this.selectedId : selectedId(),
    viewport: viewport == null ? this.viewport : viewport(),
  );
}

/// Which chart: an instrument's live chart, or a replay of it ([replayId],
/// on a fixed [timeframe]). A replay's drawings are its own: they are saved
/// under [ChartController.replayAccount], so they never show on the live chart
/// and never link to a journal trade.
class ChartKey {
  const ChartKey(this.symbol, {this.replayId, this.timeframe});

  final String symbol;
  final String? replayId;
  final Timeframe? timeframe;

  bool get isReplay => replayId != null;

  @override
  bool operator ==(Object other) =>
      other is ChartKey &&
      other.symbol == symbol &&
      other.replayId == replayId &&
      other.timeframe == timeframe;

  @override
  int get hashCode => Object.hash(symbol, replayId, timeframe);
}

/// What a replay chart is measured against at its cursor: the conditions and
/// the day so far in the replay, not today's live ones. Set by the replay.
class ChartFacts {
  const ChartFacts({required this.conditions, required this.coach});

  final List<EntryCondition> conditions;
  final CoachContext coach;
}

class ChartFactsController extends Notifier<ChartFacts?> {
  ChartFactsController(this.replayId);

  final String replayId;

  @override
  ChartFacts? build() => null;

  void set(ChartFacts facts) => state = facts;
}

final chartFactsProvider = NotifierProvider.autoDispose.family<ChartFactsController, ChartFacts?, String>(
  ChartFactsController.new,
);

/// The bars of one instrument (the live feed; replay gives another source).
final barSourceProvider = Provider.autoDispose.family<BarSource, String>(
  (ref, symbol) => LiveBarSource(ref.watch(marketDataProvider), symbol),
);

final chartBarsProvider = FutureProvider.autoDispose.family<List<Candle>, (String, Timeframe)>(
  (ref, key) => ref.watch(barSourceProvider(key.$1)).bars(key.$2, now: clock.now().toUtc(), count: 300),
);

/// One instrument's chart for the active account: tool, drawings with undo,
/// selection, viewport. Every edit is saved as a [ChartNote] at once.
class ChartController extends Notifier<ChartState> {
  ChartController(this.key);

  final ChartKey key;

  String get symbol => key.symbol;

  /// The account id a replay's notes are saved under.
  static String replayAccount(String accountId, String replayId) => 'replay:$accountId:$replayId';

  String get _accountId {
    final id = ref.read(marketsProfileProvider).activeAccount?.id ?? 'none';
    return key.replayId == null ? id : replayAccount(id, key.replayId!);
  }

  /// The conditions and coach facts the pre-trade check and the co-pilot use.
  ChartFacts facts() {
    if (key.replayId != null) {
      final f = ref.read(chartFactsProvider(key.replayId!));
      if (f != null) return f;
    }
    final profile = ref.read(marketsProfileProvider);
    return ChartFacts(
      conditions: key.isReplay ? const [] : ref.read(pairBriefProvider(symbol)).value?.conditions ?? const [],
      coach: CoachContext.from(profile, trades: ref.read(activeAccountTradesProvider), now: clock.now()),
    );
  }

  ChartNotesController get _notes => ref.read(chartNotesProvider.notifier);

  @override
  ChartState build() {
    // A new active account opens its own drawings.
    ref.watch(marketsProfileProvider.select((p) => p.activeAccount?.id));
    final account = _accountId;
    final drawings = [
      for (final n in ref.read(chartNotesProvider))
        if (!n.deleted && n.accountId == account && n.symbol.toUpperCase() == symbol.toUpperCase()) n.drawing,
    ];
    return ChartState(
      timeframe: key.timeframe ?? ref.read(pairTimeframeProvider(symbol)),
      editor: DrawingEditor(drawings: drawings),
    );
  }

  void setTool(ChartTool tool) => state = state.copyWith(tool: tool, selectedId: () => null);

  void setTimeframe(Timeframe tf) => state = state.copyWith(timeframe: tf, viewport: () => null);

  void setViewport(ChartViewport v) => state = state.copyWith(viewport: () => v);

  void select(String? id) => state = state.copyWith(selectedId: () => id);

  /// Adds [d], saves its note (no reason yet) and selects it. Back to the
  /// select tool, as on TradingView.
  Future<void> create(Drawing d) async {
    state = state.copyWith(editor: state.editor.add(d), selectedId: () => d.id, tool: ChartTool.select);
    final now = clock.now().toUtc();
    await _notes.upsert(
      ChartNote(
        id: d.id,
        accountId: _accountId,
        symbol: symbol.toUpperCase(),
        timeframe: state.timeframe,
        createdAt: now,
        updatedAt: now,
        drawing: d,
      ),
    );
  }

  Future<void> change(Drawing d) => _apply(state.editor.replace(d));

  Future<void> deleteSelected() async {
    final id = state.selectedId;
    if (id != null) await delete(id);
  }

  Future<void> delete(String id) async {
    state = state.copyWith(selectedId: () => null);
    await _apply(state.editor.delete(id));
  }

  Future<void> undo() => _apply(state.editor.undo());
  Future<void> redo() => _apply(state.editor.redo());

  /// Keyboard nudge of the selected drawing: [bars] along time, [steps] of
  /// [priceStep] along price.
  Future<void> nudge({int bars = 0, int steps = 0, required double priceStep}) async {
    final d = state.selected;
    if (d == null) return;
    await change(d.shifted(state.timeframe.duration * bars, steps * priceStep));
  }

  /// The editor after an edit, and every note made to match: drawings on the
  /// chart are live notes, others of this chart are marked deleted (kept, so
  /// undo brings them back with their reason).
  Future<void> _apply(DrawingEditor next) async {
    if (identical(next, state.editor)) return;
    final selected = state.selectedId;
    state = state.copyWith(
      editor: next,
      selectedId: () => selected != null && next.byId(selected) != null ? selected : null,
    );
    final now = clock.now().toUtc();
    final live = {for (final d in next.drawings) d.id: d};
    final account = _accountId;
    for (final n in ref.read(chartNotesProvider)) {
      if (n.accountId != account || n.symbol.toUpperCase() != symbol.toUpperCase()) continue;
      final d = live[n.id];
      if (d == null && !n.deleted) {
        await _notes.upsert(n.copyWith(deleted: true, updatedAt: now));
      } else if (d != null && (n.deleted || n.drawing != d)) {
        await _notes.upsert(n.copyWith(deleted: false, drawing: d, updatedAt: now));
      }
    }
  }

  /// The trader's reason for [noteId], then the co-pilot's reply. The reason
  /// is saved before the call, so a failed call never loses it.
  Future<CopilotReply> explain(String noteId, String reason, {required List<Candle> bars}) async {
    final words = reason.trim();
    final note = _notes.byId(noteId);
    if (note == null) return const CopilotReply(kCopilotFallback);
    final now = clock.now().toUtc();
    await _notes.update(
      noteId,
      (n) => n.copyWith(
        reason: () => words,
        updatedAt: now,
        copilot: [
          ...n.copilot,
          CopilotTurn(fromYou: true, text: words, at: now),
        ],
      ),
    );
    final profile = ref.read(marketsProfileProvider);
    final f = facts();
    final d = note.drawing;
    final stopDistance = d.kind == DrawingKind.position ? (d.entry - d.stop!).abs() : 0.0;
    final request = CopilotRequest(
      symbol: symbol.toUpperCase(),
      timeframe: state.timeframe,
      drawing: d,
      reason: words,
      strategyWords: profile.strategy?.rawText ?? '',
      conditions: f.conditions,
      coach: f.coach,
      r: stopDistance == 0 ? null : (d.target! - d.entry).abs() / stopDistance,
      lastPrice: bars.isEmpty ? null : bars.last.close,
    );
    final reply = await ref.read(copilotProvider).reflect(request);
    await _notes.update(
      noteId,
      (n) => n.copyWith(
        updatedAt: clock.now().toUtc(),
        copilot: [
          ...n.copilot,
          CopilotTurn(fromYou: false, text: reply.text, at: clock.now().toUtc()),
        ],
      ),
    );
    return reply;
  }

  Future<void> saveChecklist(String noteId, List<ChecklistAnswer> answers) =>
      _notes.update(noteId, (n) => n.copyWith(checklist: () => answers, updatedAt: clock.now().toUtc()));

  /// One keyboard step in price: a tick, else a thousandth of the price.
  double priceStep(List<Candle> bars) =>
      instrumentBySymbol(symbol)?.tickSize ?? (bars.isEmpty ? 0.0001 : bars.last.close.abs() / 1000);
}

final chartControllerProvider = NotifierProvider.autoDispose.family<ChartController, ChartState, ChartKey>(
  ChartController.new,
);
