import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Announces [message] to screen readers without moving focus.
///
/// Prefer `Semantics(liveRegion: true)` for text that is on screen; use this
/// only for events with no visible text (e.g. "pledged").
void announce(BuildContext context, String message) {
  unawaited(SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context)));
}
