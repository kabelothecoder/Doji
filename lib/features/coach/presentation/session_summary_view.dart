import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/session_summary.dart';

/// Doji Coach Phone › summary / saved: after "end", what you talked about and
/// one focus, then "save to history" or "not now".
class SessionSummaryView extends StatelessWidget {
  const SessionSummaryView({
    super.key,
    required this.summary,
    required this.saved,
    required this.onSave,
    required this.onClose,
  });

  final SessionSummary summary;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DojiColors.bg,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: DojiIconButton(
                  icon: Icons.close_rounded,
                  semanticLabel: 'close',
                  outlined: false,
                  background: Colors.transparent,
                  foreground: DojiColors.textSecondary,
                  onPressed: onClose,
                ),
              ),
              const SizedBox(height: 12),
              TerminalLine('session ended · ${summary.minutes} min', liveRegion: false),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text('what we talked about', style: DojiType.title.copyWith(fontSize: 32)),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: DojiColors.elevated1,
                  borderRadius: BorderRadius.circular(DojiRadius.card),
                  border: Border.all(color: DojiColors.separator),
                ),
                child: Column(
                  children: [
                    for (final (i, t) in summary.topics.indexed)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: i == 0 ? null : const Border(top: BorderSide(color: DojiColors.elevated2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(child: Text('>', style: DojiType.data.copyWith(fontSize: 15))),
                            const SizedBox(width: 12),
                            Expanded(child: Text(t, style: DojiType.body.copyWith(fontSize: 15))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: DojiColors.elevated1.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(DojiRadius.sheet),
                  border: Border.all(color: DojiColors.dojiGreen.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ONE FOCUS', style: DojiType.label.copyWith(fontSize: 11)),
                    const SizedBox(height: 8),
                    Text(summary.focus, style: DojiType.body.copyWith(fontSize: 19, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'coaching, not therapy · measured against your strategy. not financial advice.',
                style: DojiType.hint.copyWith(fontSize: 11, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (saved) ...[
                const TerminalLine('saved to coach history.'),
                const SizedBox(height: 12),
                DojiButton(label: 'done', onPressed: onClose),
              ] else ...[
                DojiButton(label: 'save to history', onPressed: onSave),
                DojiButton(
                  label: 'not now',
                  variant: DojiButtonVariant.text,
                  size: DojiButtonSize.small,
                  onPressed: onClose,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
