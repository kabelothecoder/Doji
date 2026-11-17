import 'drawing.dart';

/// The drawings on one chart with undo and redo. Immutable: every edit
/// returns a new editor, so one gesture (a whole drag) is one undo step.
class DrawingEditor {
  const DrawingEditor({this.drawings = const [], this.undoStack = const [], this.redoStack = const []});

  final List<Drawing> drawings;
  final List<List<Drawing>> undoStack;
  final List<List<Drawing>> redoStack;

  /// Undo keeps this many steps.
  static const maxUndo = 50;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  Drawing? byId(String id) => drawings.where((d) => d.id == id).firstOrNull;

  DrawingEditor _commit(List<Drawing> next) {
    final undo = [...undoStack, drawings];
    return DrawingEditor(
      drawings: next,
      undoStack: undo.length > maxUndo ? undo.sublist(undo.length - maxUndo) : undo,
    );
  }

  DrawingEditor add(Drawing d) => _commit([...drawings, d]);

  /// [d] in place of the drawing with its id; unchanged when there is none
  /// or nothing moved.
  DrawingEditor replace(Drawing d) {
    final i = drawings.indexWhere((x) => x.id == d.id);
    if (i < 0 || drawings[i] == d) return this;
    return _commit([...drawings]..[i] = d);
  }

  DrawingEditor move(String id, Duration dt, double dp) {
    final d = byId(id);
    return d == null ? this : replace(d.shifted(dt, dp));
  }

  DrawingEditor moveHandle(String id, DrawingHandle handle, ChartPoint p) {
    final d = byId(id);
    return d == null ? this : replace(d.withHandle(handle, p));
  }

  DrawingEditor delete(String id) =>
      byId(id) == null ? this : _commit(drawings.where((d) => d.id != id).toList());

  DrawingEditor undo() => !canUndo
      ? this
      : DrawingEditor(
          drawings: undoStack.last,
          undoStack: undoStack.sublist(0, undoStack.length - 1),
          redoStack: [...redoStack, drawings],
        );

  DrawingEditor redo() => !canRedo
      ? this
      : DrawingEditor(
          drawings: redoStack.last,
          undoStack: [...undoStack, drawings],
          redoStack: redoStack.sublist(0, redoStack.length - 1),
        );
}
