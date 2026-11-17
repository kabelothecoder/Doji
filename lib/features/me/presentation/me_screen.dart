import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../gym/data/gym_repository.dart';
import '../../home/presentation/home_controller.dart';
import '../data/badge_repository.dart';
import '../domain/me.dart';

/// The me tab (design: Doji Me Phone › profile): who you are, the year's grid,
/// the rank ladder, then badges, practice, settings and the panic flow.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(homeProfileProvider);
    final kept = ref.watch(keptDaysProvider);
    final practice = ref.watch(practiceDaysProvider);
    final streak = keptStreak(kept);
    final badges = ref.watch(badgesProvider);
    final name = profile.name ?? 'trader';
    final cur = kRanks.indexWhere((r) => r.$1 == profile.rank).clamp(0, kRanks.length - 1);

    return MeScaffold(
      title: 'me',
      trailing: DojiIconButton(
        icon: Icons.settings_outlined,
        semanticLabel: 'settings',
        onPressed: () => context.push(Routes.settings),
      ),
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DojiColors.elevated2,
                  border: Border.all(color: DojiColors.separator),
                ),
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: DojiType.data.copyWith(fontSize: 20, color: DojiColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: DojiType.headline.copyWith(fontSize: 22)),
                  const SizedBox(height: 8),
                  RankPill(code: kRanks[cur].$1, name: kRanks[cur].$2),
                ],
              ),
            ),
          ],
        ),
        _Card(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Eyebrow('DOJI SCORE'),
                  // TODO(next-slice): the real score once its model exists.
                  Text('812', style: DojiType.score.copyWith(fontSize: 48)),
                ],
              ),
              const _SampleTag('sample data'),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _Eyebrow('STREAK'),
                  Text(
                    '$streak ${streak == 1 ? 'day' : 'days'}',
                    style: DojiType.data.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _Eyebrow('DOJI GRID · ${clock.now().year}')),
                  DojiButton(
                    label: 'share',
                    icon: const Icon(Icons.ios_share, size: 18),
                    variant: DojiButtonVariant.ghost,
                    size: DojiButtonSize.small,
                    expand: false,
                    onPressed: () => context.push(Routes.shareCard),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              YearHalf(label: 'jan – jun', first: true, kept: kept, practice: practice),
              const SizedBox(height: 12),
              YearHalf(label: 'jul – dec', first: false, kept: kept, practice: practice),
              const SizedBox(height: 12),
              const Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  _Eyebrow('kept day = reviewed trades all A or B · dot = practice'),
                  GridLegendScale(),
                ],
              ),
            ],
          ),
        ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Eyebrow('RANK LADDER'),
              const SizedBox(height: 8),
              for (var i = 0; i < kRanks.length; i++) _RankRow(i: i, cur: cur),
              const Divider(height: 24, color: DojiColors.separator),
              const _Eyebrow('WHAT MOVES THE SCORE'),
              const SizedBox(height: 6),
              for (final (t, up) in const [
                ('keep the morning pledge', true),
                ('close your day', true),
                ('journal or check in', true),
                ('stop at your limits', true),
                ('break one of your rules', false),
              ])
                _MoveRow(text: t, raises: up),
            ],
          ),
        ),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _MenuRow(
                icon: Icons.workspace_premium_outlined,
                label: 'badges',
                value: '${badges.where((b) => b.earned).length} of ${badges.length}',
                onTap: () => context.go(Routes.meBadges),
              ),
              _MenuRow(
                icon: Icons.psychology_outlined,
                label: 'mind toolkit',
                onTap: () => context.go(Routes.mind),
                divider: true,
              ),
              _MenuRow(
                icon: Icons.forum_outlined,
                label: 'coach history',
                value: 'saved sessions',
                onTap: () => context.go(Routes.coachHistory),
                divider: true,
              ),
              _MenuRow(
                icon: Icons.fitness_center_outlined,
                label: 'practice',
                value: 'backtest, replay, gym',
                onTap: () => context.go(Routes.mePractice),
                divider: true,
              ),
              _MenuRow(
                icon: Icons.settings_outlined,
                label: 'settings',
                onTap: () => context.push(Routes.settings),
                divider: true,
              ),
            ],
          ),
        ),
        DojiPressable(
          onPressed: () => context.push(Routes.panic),
          borderRadius: BorderRadius.circular(DojiRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DojiRadius.card),
              border: Border.all(color: DojiColors.separator),
            ),
            child: Row(
              children: [
                const Icon(Icons.air, size: 22, color: DojiColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'i blew my account',
                        style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
                      ),
                      Text(
                        'a calm minute, whenever you need it',
                        style: DojiType.callout.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: DojiColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Badges (design: Doji Me Phone › badges): earned = green solid, locked = dashed grey.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);
    return MeScaffold(
      title: 'badges',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.me),
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final b in badges) SizedBox(width: w, child: _BadgeCard(b))],
            );
          },
        ),
        Text(
          'a kept day = every reviewed trade graded A or B. days without trades never break a streak.',
          style: DojiType.callout.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

/// The me tab's page: title row (optional back and trailing), then [children] 14 apart.
class MeScaffold extends StatelessWidget {
  const MeScaffold({super.key, required this.title, required this.children, this.trailing, this.onBack});

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DojiColors.bg,
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  if (onBack != null) ...[
                    DojiIconButton(icon: Icons.arrow_back_rounded, semanticLabel: 'back', onPressed: onBack),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Semantics(header: true, child: Text(title, style: DojiType.title)),
                  ),
                  ?trailing,
                ],
              ),
              for (final c in children) ...[const SizedBox(height: 14), c],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      border: Border.all(color: DojiColors.separator),
    ),
    child: child,
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: DojiType.label.copyWith(fontSize: 11));
}

class _SampleTag extends StatelessWidget {
  const _SampleTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: DojiColors.separator),
    ),
    child: Text(text, style: DojiType.label.copyWith(fontSize: 10, color: DojiColors.textSecondary)),
  );
}

/// Half a year (27 weeks × 7 days from 1 jan or 2 jul), shared by the me tab
/// and the share card. Cells come from [dayCell] (journal kept days); drill
/// days carry a dot, like Home's MiniGrid.
class YearHalf extends StatelessWidget {
  const YearHalf({
    super.key,
    required this.label,
    required this.first,
    required this.kept,
    required this.practice,
    this.gap = 2,
    this.labelStyle,
    this.labelGap = 6,
  });

  final String label;
  final bool first;
  final Map<DateTime, bool> kept;
  final Set<DateTime> practice;
  final double gap;
  final TextStyle? labelStyle;
  final double labelGap;

  static const _weeks = 27;

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final offset = first ? 0 : _weeks * 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: labelStyle ?? DojiType.label.copyWith(fontSize: 10, color: DojiColors.textSecondary),
        ),
        SizedBox(height: labelGap),
        Semantics(
          label: 'doji grid $label',
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, box) {
                final cell = (box.maxWidth - gap * (_weeks - 1)) / _weeks;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var w = 0; w < _weeks; w++)
                      Column(
                        children: [
                          for (var d = 0; d < 7; d++) ...[
                            if (d > 0) SizedBox(height: gap),
                            _cell(DateTime(now.year, 1, 1 + offset + w * 7 + d), cell, now),
                          ],
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(DateTime day, double size, DateTime now) {
    final c = GridCell(size: size, state: dayCell(day, kept, now));
    if (!practice.contains(day)) return c;
    final dot = (size / 3).clamp(2, 6).toDouble();
    return Stack(
      alignment: Alignment.center,
      children: [
        c,
        Container(
          width: dot,
          height: dot,
          decoration: const BoxDecoration(color: DojiColors.textPrimary, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

/// "less ▪▪▪▪▪ more".
class GridLegendScale extends StatelessWidget {
  const GridLegendScale({super.key});

  @override
  Widget build(BuildContext context) {
    final s = DojiType.label.copyWith(fontSize: 10, color: DojiColors.textSecondary);
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('less', style: s),
          const SizedBox(width: 4),
          for (final c in DojiColors.grid) ...[
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 3),
          ],
          Text('more', style: s),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.i, required this.cur});

  final int i;
  final int cur;

  @override
  Widget build(BuildContext context) {
    final (code, name) = kRanks[i];
    final reached = i <= cur;
    final where = i < cur
        ? 'passed'
        : i == cur
        ? 'you are here'
        : i == cur + 1
        ? 'next'
        : '';
    final fg = reached ? DojiColors.textPrimary : DojiColors.textSecondary;
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DojiColors.elevated2)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reached ? DojiColors.dojiGreen : Colors.transparent,
                border: Border.all(color: reached ? DojiColors.dojiGreen : const Color(0xFF4A4E55), width: 2),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 40,
              child: Text(
                code,
                style: DojiType.data.copyWith(
                  fontSize: 14,
                  color: fg,
                  fontWeight: i == cur ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: Text(name, style: DojiType.callout.copyWith(fontSize: 14, color: fg)),
            ),
            Text(where, style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.text, required this.raises});

  final String text;
  final bool raises;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          Icon(
            raises ? Icons.add : Icons.remove,
            size: 16,
            color: raises ? DojiColors.dojiGreen : DojiColors.tiltOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: DojiType.callout.copyWith(fontSize: 14, color: DojiColors.textPrimary)),
          ),
          Text(
            raises ? 'raises' : 'lowers',
            style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.divider = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: DojiPressable(
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          border: divider ? const Border(top: BorderSide(color: DojiColors.elevated2)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: DojiColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: DojiType.body.copyWith(fontSize: 16))),
            if (value != null) Text(value!, style: DojiType.label.copyWith(color: DojiColors.textSecondary)),
            const Icon(Icons.chevron_right, size: 20, color: DojiColors.textTertiary),
          ],
        ),
      ),
    ),
  );
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard(this.b);

  final MeBadge b;

  @override
  Widget build(BuildContext context) {
    final border = b.earned ? DojiColors.dojiGreen : const Color(0xFF3A3D42);
    return Semantics(
      label: '${b.title} badge, ${b.earned ? 'earned' : 'locked'}. ${b.line}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DojiColors.elevated1,
            borderRadius: BorderRadius.circular(DojiRadius.card),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: b.earned ? DojiColors.dojiGreen.withValues(alpha: .1) : Colors.transparent,
                  border: Border.all(color: border),
                ),
                child: Text(
                  b.earned ? b.glyph : '—',
                  style: DojiType.data.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: b.earned ? DojiColors.textPrimary : DojiColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                b.title,
                style: DojiType.callout.copyWith(
                  fontWeight: FontWeight.w600,
                  color: b.earned ? DojiColors.textPrimary : DojiColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(b.line, style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
