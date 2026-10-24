import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../onboarding/domain/sessions.dart';
import 'home_card.dart';

/// Design spec `OpenCard`: the open for today. Pending shows "60 seconds";
/// done shows time and mood. Status is a tick or ring plus a word.
class OpenCard extends StatelessWidget {
  const OpenCard({super.key, required this.doneAt, required this.mood, required this.onStart});

  final DateTime? doneAt;
  final String? mood;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final done = doneAt != null;
    final sub = done
        ? 'done at ${hhmm(doneAt!.hour * 60 + doneAt!.minute)} · ${mood ?? 'no mood'}'
        : '60 seconds';
    return DojiPressable(
      onPressed: onStart,
      semanticLabel: 'the open, $sub, ${done ? 'done' : 'waiting'}',
      borderRadius: BorderRadius.circular(DojiRadius.card),
      child: HomeCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? DojiColors.dojiGreen : Colors.transparent,
                  border: Border.all(color: done ? DojiColors.dojiGreen : DojiColors.textSecondary, width: 2),
                ),
                child: done ? const Icon(Icons.check_rounded, size: 18, color: DojiColors.bg) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'the open',
                      style: DojiType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(sub, style: DojiType.hint),
                  ],
                ),
              ),
              Text(
                done ? 'done' : 'waiting',
                style: DojiType.hint.copyWith(color: done ? DojiColors.dojiGreen : DojiColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
