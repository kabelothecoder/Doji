import 'package:flutter/widgets.dart';

import '../../domain/onboarding_step.dart';

/// Called by inputs when the draft changes. `advance: true` asks the screen to
/// continue after the handoff's 350ms auto-advance delay (single choice).
typedef DraftChanged = void Function(Object? draft, {bool advance});

/// Everything an answer widget needs; inputs are fully controlled.
@immutable
class StepInputArgs {
  const StepInputArgs({
    required this.step,
    required this.answers,
    required this.draft,
    required this.onChanged,
    required this.onSubmit,
    required this.wide,
    this.hasError = false,
  });

  final OnboardingStep step;
  final Answers answers;
  final Object? draft;
  final DraftChanged onChanged;

  /// "continue" with the current draft (e.g. return key in a text field).
  final VoidCallback onSubmit;

  /// Windows layout: bigger chips, key hints.
  final bool wide;
  final bool hasError;

  Map<String, Object?> get draftMap =>
      draft is Map ? (draft! as Map).map((k, v) => MapEntry(k.toString(), v)) : <String, Object?>{};

  List<String> get draftList => draft is List ? (draft! as List).whereType<String>().toList() : <String>[];
}

/// Fills the available height and aligns [children] like the handoff's
/// `flex:1; justify-content:flex-end`, but scrolls instead of clipping when
/// text is scaled up (200%). Uses min-height, not intrinsics, so scrollables
/// and LayoutBuilders inside are fine.
class FillScroll extends StatelessWidget {
  const FillScroll({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
    this.reverse = true,
  });

  final List<Widget> children;
  final MainAxisAlignment alignment;

  /// Start scrolled to the bottom, where the input is.
  final bool reverse;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      reverse: reverse,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignment,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

/// Lays children out in [columns] equal-width columns like the handoff's CSS
/// grid: cells in a row share the tallest height, and rows grow with text
/// size instead of clipping (unlike a fixed-extent GridView).
class EqualColumns extends StatelessWidget {
  const EqualColumns({super.key, required this.columns, required this.children, this.gap = 8});

  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cols = columns.clamp(1, children.isEmpty ? 1 : children.length);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final cells = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (j > 0) cells.add(SizedBox(width: gap));
        final k = i + j;
        cells.add(Expanded(child: k < children.length ? children[k] : const SizedBox.shrink()));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
