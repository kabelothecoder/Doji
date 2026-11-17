import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../journal/domain/formatting.dart';
import '../../me/presentation/me_screen.dart' show MeScaffold;
import '../data/coach_session_repository.dart';
import '../domain/coach.dart';
import '../domain/coach_session.dart';

/// Coach history (me tab): every saved session, newest first. Reads
/// [CoachSessionRepository] (`doji.coach.v1`).
class CoachHistoryScreen extends ConsumerWidget {
  const CoachHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(savedCoachSessionsProvider);
    return MeScaffold(
      title: 'coach history',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.me),
      children: [
        if (sessions.isEmpty)
          Text(
            'no saved sessions yet. after a session, "save to history" keeps it here, on this device.',
            style: DojiType.callout,
          )
        else
          for (final s in sessions) _SessionRow(session: s),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final CoachSession session;

  @override
  Widget build(BuildContext context) {
    final local = session.startedAt.toLocal();
    final first = session.turns.where((t) => t.speaker == CoachSpeaker.you).firstOrNull?.text ?? '';
    final lines = session.turns.length;
    return DojiPressable(
      onPressed: () => unawaited(context.push(Routes.coachTranscript(session.id))),
      semanticLabel: '${dayLabel(local)} ${clockLabel(local)}, $lines lines, $first',
      borderRadius: BorderRadius.circular(DojiRadius.card),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DojiColors.elevated1,
          borderRadius: BorderRadius.circular(DojiRadius.card),
          border: Border.all(color: DojiColors.separator),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dayLabel(local)} · ${clockLabel(local)} · $lines lines',
                    style: DojiType.hint.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DojiType.body.copyWith(fontSize: 15),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: DojiColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// One saved session, read back: who said what, and when in the session.
class CoachTranscriptScreen extends ConsumerWidget {
  const CoachTranscriptScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(savedCoachSessionsProvider).where((s) => s.id == sessionId).firstOrNull;
    void back() => context.canPop() ? context.pop() : context.go(Routes.coachHistory);
    if (session == null) {
      return MeScaffold(
        title: 'transcript',
        onBack: back,
        children: [Text('this session is no longer on this device.', style: DojiType.callout)],
      );
    }
    final local = session.startedAt.toLocal();
    String at(DateTime t) {
      final d = t.difference(session.startedAt);
      final m = d.inMinutes.clamp(0, 999).toString().padLeft(2, '0');
      final s = (d.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return MeScaffold(
      title: 'transcript',
      onBack: back,
      children: [
        TerminalLine('${dayLabel(local)} · ${clockLabel(local)} · ${session.voice.label}', liveRegion: false),
        for (final t in session.turns)
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.speaker == CoachSpeaker.you ? 'you' : 'doji'} · ${at(t.at)}',
                  style: DojiType.hint.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(t.text, style: DojiType.body.copyWith(fontSize: 15, height: 1.45)),
              ],
            ),
          ),
        Text(
          'coaching, not therapy · measured against your strategy. not financial advice.',
          style: DojiType.hint.copyWith(fontSize: 11, height: 1.5),
        ),
      ],
    );
  }
}
