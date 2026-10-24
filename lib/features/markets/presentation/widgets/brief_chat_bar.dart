import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Handoff 1b `BriefChatBar`: the floating glass bar under the brief.
/// Tapping it opens the chat sheet scoped to this brief; the mic opens it
/// listening (or typing, when voice isn't on this plan or device). Grows
/// with large text instead of clipping.
class BriefChatBar extends StatelessWidget {
  const BriefChatBar({super.key, required this.onAsk, required this.onVoice});

  final VoidCallback onAsk;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final target = DojiTokens.of(context).minTarget;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 12))],
      ),
      child: GlassSurface(
        radius: 30,
        tint: DojiColors.elevated2,
        fillOpacity: 0.62,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: [
              Expanded(
                child: DojiPressable(
                  onPressed: onAsk,
                  semanticLabel: 'ask about this brief',
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: target),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            style: DojiType.terminal,
                            children: const [
                              TextSpan(
                                text: '> ',
                                style: TextStyle(color: DojiColors.dojiGreen),
                              ),
                              TextSpan(text: 'ask about this brief'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DojiIconButton(
                  icon: Icons.mic_rounded,
                  semanticLabel: 'ask by voice',
                  filled: true,
                  onPressed: onVoice,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
