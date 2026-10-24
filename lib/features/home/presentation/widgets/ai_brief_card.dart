import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../markets/domain/instrument_catalog.dart';
import '../../../markets/domain/market_format.dart';
import '../../../markets/domain/pair_brief.dart';
import '../../../markets/presentation/pair_detail_controller.dart';
import '../../../onboarding/domain/user_zone.dart';
import 'home_card.dart';

/// Design spec `AiBriefCard`: the brief for the selected instrument, measured
/// against the user's strategy. Conditions are shape + word; the "not
/// financial advice" footer is required. The conditions come from the same
/// brief as Markets 1b ([pairBriefProvider]); "open the brief" goes there.
///
/// The conditions are measured, not written, so they show on every plan; the
/// free plan's one brief a day is counted on 1b.
class AiBriefCard extends ConsumerStatefulWidget {
  const AiBriefCard({super.key, required this.instruments});

  final List<String> instruments;

  @override
  ConsumerState<AiBriefCard> createState() => _AiBriefCardState();
}

class _AiBriefCardState extends ConsumerState<AiBriefCard> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final symbol = widget.instruments[_selected.clamp(0, widget.instruments.length - 1)];
    final brief = ref.watch(pairBriefProvider(symbol));
    final zone = userZoneFromProfile(ref.watch(marketsProfileProvider));
    final b = brief.value;
    final met = b?.metCount ?? 0;
    final total = b?.conditions.length ?? 0;
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: HomeEyebrow('AI BRIEF')),
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    for (var i = 0; i < widget.instruments.length && i < 3; i++)
                      _InstrumentChip(
                        instrument: widget.instruments[i],
                        selected: i == _selected,
                        onTap: () => setState(() => _selected = i),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (b == null)
            brief.hasError
                ? const TerminalLine("couldn't measure your conditions.", tone: TerminalTone.tilt)
                : const TerminalLine('measuring against your strategy', liveRegion: false)
          else ...[
            Text.rich(
              TextSpan(
                style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
                children: [
                  if (b.strategyName case final name?) ...[
                    const TextSpan(text: 'measured against your strategy: '),
                    TextSpan(
                      text: name,
                      style: DojiType.config.copyWith(color: DojiColors.textPrimary),
                    ),
                    TextSpan(text: '. $met of $total conditions are in place.'),
                  ] else
                    TextSpan(text: 'measured against your rules. $met of $total conditions are in place.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final c in b.conditions) _ConditionRow(c),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DojiColors.separator)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    b == null
                        ? 'not financial advice'
                        : 'not financial advice · updated ${clockTime(zone, b.updatedAt)}',
                    style: DojiType.hint.copyWith(fontSize: 11),
                  ),
                ),
                DojiButton(
                  label: 'open the brief',
                  semanticLabel: 'open the ${displaySymbol(symbol)} brief',
                  variant: DojiButtonVariant.ghost,
                  size: DojiButtonSize.small,
                  expand: false,
                  onPressed: () => context.push(Routes.pairDetail(symbol)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentChip extends StatelessWidget {
  const _InstrumentChip({required this.instrument, required this.selected, required this.onTap});

  final String instrument;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final target = DojiTokens.of(context).minTarget;
    return Semantics(
      button: true,
      selected: selected,
      label: instrumentLabel(instrument),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: target),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selected ? DojiColors.dojiGreen : DojiColors.separator),
                ),
                child: Text(
                  instrumentLabel(instrument),
                  style: DojiType.hint.copyWith(
                    color: selected ? DojiColors.textPrimary : DojiColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Home's compact row (Doji Home): a dot and the status word ("met", "not
/// met", "waiting"), so it never relies on colour.
class _ConditionRow extends StatelessWidget {
  const _ConditionRow(this.c);

  final EntryCondition c;

  @override
  Widget build(BuildContext context) {
    final word = c.status.label.toLowerCase();
    final (Color ring, Color? fill, Color text) = switch (c.status) {
      ConditionStatus.met => (DojiColors.dojiGreen, DojiColors.dojiGreen, DojiColors.textPrimary),
      ConditionStatus.notMet => (DojiColors.tiltOrange, null, DojiColors.tiltOrange),
      ConditionStatus.waiting => (DojiColors.textSecondary, null, DojiColors.textSecondary),
    };
    return Semantics(
      container: true,
      label: '${c.text}, $word',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: DojiColors.divider)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(color: ring, width: 2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.text,
                  style: DojiType.callout.copyWith(fontSize: 14, color: DojiColors.textPrimary),
                ),
              ),
              Text(word, style: DojiType.hint.copyWith(color: text)),
            ],
          ),
        ),
      ),
    );
  }
}
