import 'package:flutter/material.dart';

import '../theme/typography.dart';

/// Desktop key hints in Geist Mono: "1–4 PICK · ↵ CONTINUE · ESC BACK".
/// Decorative for screen readers (the actions are exposed as buttons).
class KeyHints extends StatelessWidget {
  const KeyHints(this.hints, {super.key});

  final List<String> hints;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(hints.join(' · ').toUpperCase(), style: DojiType.hint, textAlign: TextAlign.end),
  );
}
