import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/doji_haptics.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/home_models.dart';
import 'home_card.dart';

/// Design spec `SetupChecklist`: three day-zero tasks. Each tick is a small
/// win: fill, scale bounce, light haptic. The parent hides it when all three
/// are done.
class SetupChecklist extends ConsumerWidget {
  const SetupChecklist({super.key, required this.done, required this.onToggle});

  final Set<SetupTask> done;
  final ValueChanged<SetupTask> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: DojiTokens.of(context).minTarget),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('finish setup', style: DojiType.headline.copyWith(fontSize: 17)),
                  ),
                ),
                Text(
                  '${done.length}/${SetupTask.values.length}',
                  style: DojiType.config.copyWith(color: DojiColors.textSecondary),
                ),
              ],
            ),
          ),
          for (final task in SetupTask.values)
            _TaskRow(
              task: task,
              done: done.contains(task),
              onTap: () {
                if (!done.contains(task)) ref.read(hapticsProvider).light();
                onToggle(task);
              },
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.done, required this.onTap});

  final SetupTask task;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = DojiMotion.reduced(context);
    return DojiPressable(
      onPressed: onTap,
      checked: done,
      semanticLabel: '${task.title}, ${task.sub}',
      showPressedOverlay: false,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DojiColors.divider)),
        ),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              key: ValueKey(done),
              tween: Tween(begin: done && !reduced ? 1.15 : 1, end: 1),
              duration: reduced ? Duration.zero : const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? DojiColors.dojiGreen : Colors.transparent,
                  border: Border.all(color: done ? DojiColors.dojiGreen : const Color(0xFF4A4E55), width: 2),
                ),
                child: done ? const Icon(Icons.check_rounded, size: 16, color: DojiColors.bg) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: DojiType.callout.copyWith(
                        color: done ? DojiColors.textSecondary : DojiColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(task.sub, style: DojiType.hint),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: DojiColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
