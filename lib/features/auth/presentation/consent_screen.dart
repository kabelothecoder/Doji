import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_states.dart';

/// Handoff A7 "18+ and consent": "new accounts only, after the first
/// successful sign-in. Both boxes are required; the CTA stays disabled until
/// both are ticked." No back and no way past it: launch brings it back until
/// it is agreed (`ConsentRepository`).
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _adult = false;
  bool _personalInfo = false;
  bool _offline = false;

  Future<void> _agree() async {
    setState(() => _offline = false);
    final ok = await ref.read(authFlowProvider.notifier).acceptConsent();
    if (!mounted) return;
    if (ok) {
      context.go(ref.read(authFlowProvider).next);
    } else if (ref.read(authFlowProvider).offline) {
      setState(() => _offline = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowProvider);
    if (_offline) {
      return AuthOfflineView(
        onRetry: () => unawaited(_agree()),
        onBack: () => setState(() => _offline = false),
      );
    }
    final ready = _adult && _personalInfo && !flow.sending;
    return PopScope(
      canPop: false,
      child: AuthScaffold(
        prompt: 'auth --consent',
        body: [
          const SizedBox(height: 8),
          const AuthHeadline('before you start.'),
          const SizedBox(height: 24),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: DojiColors.elevated1,
              borderRadius: BorderRadius.circular(DojiRadius.card),
            ),
            child: Column(
              children: [
                _ConsentRow(
                  title: "I'm 18 or older.",
                  sub: 'doji talks about trading, which carries real financial risk.',
                  value: _adult,
                  onChanged: flow.sending ? null : (v) => setState(() => _adult = v),
                ),
                const Divider(height: 1, thickness: 1, color: DojiColors.divider),
                _ConsentRow(
                  title: 'I consent to doji processing my personal information.',
                  sub: 'under POPIA, to run my account and coaching. withdraw anytime in settings.',
                  value: _personalInfo,
                  onChanged: flow.sending ? null : (v) => setState(() => _personalInfo = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final doc in const ['terms of use', 'privacy policy'])
                DojiButton(
                  label: doc,
                  variant: DojiButtonVariant.ghost,
                  size: DojiButtonSize.small,
                  expand: false,
                  onPressed: () => _showDocument(context, doc),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const _NeutralNote('Doji is coaching and analysis software, not financial advice.'),
        ],
        actions: [
          if (flow.message case final msg?) TerminalLine(msg, tone: TerminalTone.tilt, cursor: true),
          DojiButton(
            label: flow.sending ? 'saving…' : 'agree and continue',
            onPressed: ready ? () => unawaited(_agree()) : null,
          ),
        ],
      ),
    );
  }
}

// TODO(backend): open the published terms and privacy policy (hosted pages,
// via url_launcher) once they exist. Until then the sheet says so plainly.
void _showDocument(BuildContext context, String doc) => unawaited(
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: DojiColors.elevated1,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc, style: DojiType.headline),
            const SizedBox(height: 12),
            Text('the full $doc is published here before doji launches.', style: DojiType.callout),
            const SizedBox(height: 20),
            DojiButton(label: 'close', variant: DojiButtonVariant.outline, onPressed: () => Navigator.pop(c)),
          ],
        ),
      ),
    ),
  ),
);

/// One required box: a green tick and the word "checked" for screen readers.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.title, required this.sub, required this.value, required this.onChanged});

  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DojiPressable(
      checked: value,
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: '$title $sub',
      child: Padding(
        padding: const EdgeInsets.all(DojiSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? DojiColors.dojiGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: value ? DojiColors.dojiGreen : DojiColors.textSecondary, width: 2),
              ),
              child: value ? const Icon(Icons.check_rounded, size: 18, color: DojiColors.bg) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DojiType.body.copyWith(
                      color: DojiColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(sub, style: DojiType.callout.copyWith(height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The handoff's grey `InfoNote` (hairline border, info glyph).
class _NeutralNote extends StatelessWidget {
  const _NeutralNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'note: $text',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DojiRadius.card),
            border: Border.all(color: DojiColors.separator),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: DojiColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
