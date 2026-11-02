import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../../markets/domain/currency.dart';
import '../../onboarding/domain/onboarding_catalog.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/prop_rules.dart';
import '../../onboarding/domain/sessions.dart';
import '../../onboarding/presentation/steps/step_input.dart';
import '../../onboarding/presentation/steps/text_inputs.dart';
import '../domain/condition_eval.dart';
import '../domain/trading_account.dart';
import 'accounts_controller.dart';

/// Edits one account: name, kind, currency, starting size, risk and limits,
/// prop rules, and the strategy (its own words + the conditions doji
/// measures). Nothing is saved until "save". No design file exists for it
/// (design/SOURCE.md › Missing); it is built from design-system parts.
class AccountEditorScreen extends ConsumerStatefulWidget {
  const AccountEditorScreen({super.key, required this.accountId, this.scrollToStrategy = false});

  final String accountId;

  /// Opened from MEASURED AGAINST: scroll to the strategy.
  final bool scrollToStrategy;

  @override
  ConsumerState<AccountEditorScreen> createState() => _AccountEditorScreenState();
}

class _AccountEditorScreenState extends ConsumerState<AccountEditorScreen> {
  final _strategyKey = GlobalKey();
  late TradingAccount? _draft = ref
      .read(accountsControllerProvider)
      .accounts
      .where((a) => a.id == widget.accountId)
      .firstOrNull;
  late final _name = TextEditingController(text: _draft?.name ?? '');
  late final _size = TextEditingController(text: _fmt(_draft?.startingSize));
  late final _manual = TextEditingController();
  bool _dirty = false;

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

  @override
  void initState() {
    super.initState();
    if (widget.scrollToStrategy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _strategyKey.currentContext;
        if (c != null && c.mounted) unawaited(Scrollable.ensureVisible(c, duration: Duration.zero));
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _size.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _edit(TradingAccount Function(TradingAccount a) f) => setState(() {
    _draft = f(_draft!);
    _dirty = true;
  });

  TradingRules get _rules => _draft!.rules ?? const TradingRules();
  StrategyProfile get _strategy => _draft!.strategy ?? const StrategyProfile();
  List<StrategyCondition> get _conditions => _strategy.conditions;

  void _setConditions(List<StrategyCondition> next) =>
      _edit((a) => a.copyWith(strategy: _strategy.copyWith(conditions: next)));

  void _back() => context.canPop() ? context.pop() : context.go(Routes.accounts);

  Future<void> _save() async {
    final name = _name.text.trim();
    final account = _draft!.copyWith(
      name: name.isEmpty ? _draft!.kind.label : name,
      startingSize: double.tryParse(_size.text.trim()),
    );
    await ref.read(accountsControllerProvider.notifier).save(account);
    if (mounted) _back();
  }

  Future<void> _close() async {
    if (_dirty) {
      final drop = await showDojiAlert(
        context,
        title: 'leave without saving?',
        message: 'your changes to this account are not saved.',
        destructiveLabel: 'leave',
      );
      if (!drop || !mounted) return;
    }
    _back();
  }

  Future<void> _delete() async {
    final a = _draft!;
    final ok = await showDojiAlert(
      context,
      title: 'delete ${a.name}?',
      message: 'its rules and strategy go. trades you logged on it stay in the journal under all accounts.',
      destructiveLabel: 'delete',
    );
    if (!ok || !mounted) return;
    await ref.read(accountsControllerProvider.notifier).delete(a.id);
    if (mounted) _back();
  }

  @override
  Widget build(BuildContext context) {
    final a = _draft;
    if (a == null) {
      return AuthScaffold(
        leading: AuthLeading.back,
        onLeading: _back,
        body: [Text('this account no longer exists.', style: DojiType.body)],
      );
    }
    final canDelete = ref.watch(accountsControllerProvider).accounts.length > 1;
    final prop = a.prop;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: AuthScaffold(
        leading: AuthLeading.back,
        onLeading: () => unawaited(_close()),
        bodyGap: 0,
        actions: [DojiButton(label: 'save', onPressed: () => unawaited(_save()))],
        body: [
          Semantics(header: true, child: Text('edit account', style: DojiType.largeTitle)),
          const SizedBox(height: 20),
          const _Label('NAME'),
          DojiTextField(
            controller: _name,
            hint: a.kind.label,
            semanticLabel: 'account name',
            large: false,
            onChanged: (_) => _dirty = true,
          ),
          const SizedBox(height: 20),
          const _Label('KIND'),
          _Chips(
            options: {for (final k in AccountKind.values) k: k.label},
            selected: a.kind,
            onTap: (k) => _edit((a) => a.copyWith(kind: k)),
          ),
          const SizedBox(height: 20),
          const _Label('ACCOUNT CURRENCY'),
          _Chips(
            options: {for (final c in AccountCurrency.values) c.code: c.code},
            selected: a.accountCurrency,
            mono: true,
            onTap: (c) => _edit((a) => a.copyWith(accountCurrency: c)),
          ),
          const SizedBox(height: 20),
          const _Label('STARTING SIZE'),
          DojiTextField(
            controller: _size,
            hint: 'e.g. 10000',
            helper: 'loss % and the prop drawdown are measured against it.',
            semanticLabel: 'starting size in ${a.accountCurrency}',
            large: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => _dirty = true,
          ),
          const SizedBox(height: 28),
          const _Section('rules'),
          DojiStepper(
            label: 'risk per trade',
            value: _rules.riskPerTrade ?? 1,
            min: 0.25,
            max: 5,
            step: 0.25,
            format: (v) => '${_fmt(v)}%',
            semanticUnit: 'percent',
            onChanged: (v) => _edit((a) => a.copyWith(rules: _rules.copyWith(riskPerTrade: v))),
          ),
          const SizedBox(height: 12),
          DojiStepper(
            label: 'max trades a day',
            value: (_rules.maxTradesPerDay ?? 3).toDouble(),
            min: 1,
            max: 20,
            format: (v) => _fmt(v),
            semanticUnit: 'trades',
            onChanged: (v) => _edit((a) => a.copyWith(rules: _rules.copyWith(maxTradesPerDay: v.round()))),
          ),
          const SizedBox(height: 12),
          DojiStepper(
            label: 'daily loss limit',
            value: _rules.dailyLossLimit ?? 2,
            min: 0.5,
            max: 10,
            step: 0.5,
            format: (v) => '${_fmt(v)}%',
            semanticUnit: 'percent',
            onChanged: (v) => _edit((a) => a.copyWith(rules: _rules.copyWith(dailyLossLimit: v))),
          ),
          const SizedBox(height: 28),
          const _Section('prop rules'),
          _Chips(
            options: const {false: 'none', true: 'this account has prop rules'},
            selected: prop != null,
            onTap: (on) =>
                _edit((a) => on ? a.copyWith(prop: a.prop ?? const PropRules()) : a.copyWith(prop: null)),
          ),
          if (prop != null) ...[
            const SizedBox(height: 12),
            _PropFields(
              prop: prop,
              onChanged: (p) => _edit((a) => a.copyWith(prop: p)),
            ),
          ],
          const SizedBox(height: 28),
          KeyedSubtree(key: _strategyKey, child: const _Section('strategy')),
          Text('in your own words. say it or type it.', style: DojiType.callout),
          const SizedBox(height: 12),
          StrategyInput(
            StepInputArgs(
              step: buildOnboardingSteps().firstWhere((s) => s.id == StepIds.strategy),
              answers: const {},
              draft: {'raw': ?_strategy.rawText, 'template': ?_strategy.template},
              onChanged: (v, {advance = false}) {
                final m = v is Map ? v : const {};
                _edit(
                  (a) => a.copyWith(
                    strategy: _strategy.copyWith(
                      rawText: m['raw'] as String?,
                      template: m['template'] as String?,
                      source: m['source'] as String?,
                    ),
                  ),
                );
              },
              onSubmit: () {},
              wide: false,
            ),
            parsing: false,
          ),
          const SizedBox(height: 20),
          const _Label('CONDITIONS DOJI MEASURES'),
          Text(
            'doji measures these from the clock, the calendar, the journal and the chart. '
            'anything else goes in as your own: doji shows it as "$kCheckOnYourChart" and never guesses.',
            style: DojiType.callout,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _conditions.length; i++)
            _ConditionTile(
              label: conditionLabel(_conditions[i]),
              onRemove: () => _setConditions([..._conditions]..removeAt(i)),
            ),
          const SizedBox(height: 12),
          const _Label('ADD'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in _addable)
                DojiChoiceChip(
                  label: conditionLabel(c),
                  selected: false,
                  style: DojiChoiceStyle.chip,
                  minHeight: 44,
                  onTap: () => _setConditions([..._conditions, c]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DojiTextField(
            controller: _manual,
            hint: 'a rule of your own, e.g. price above the 50 ema on H1',
            semanticLabel: 'add a rule of your own',
            large: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addManual(),
            trailing: DojiIconButton(
              icon: Icons.add_rounded,
              semanticLabel: 'add rule',
              onPressed: _addManual,
            ),
          ),
          if (canDelete) ...[
            const SizedBox(height: 32),
            DojiButton(
              label: 'delete this account',
              variant: DojiButtonVariant.text,
              onPressed: () => unawaited(_delete()),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _addManual() {
    final text = _manual.text.trim();
    if (text.isEmpty) return;
    _manual.clear();
    _setConditions([..._conditions, StrategyCondition(kind: ConditionKind.manual, text: text)]);
  }

  /// Measurable conditions not on the list yet.
  List<StrategyCondition> get _addable {
    final all = [
      const StrategyCondition(kind: ConditionKind.session),
      for (final s in const [
        TradingSession.sydney,
        TradingSession.tokyo,
        TradingSession.london,
        TradingSession.newYork,
      ])
        StrategyCondition(kind: ConditionKind.session, session: s.key),
      const StrategyCondition(kind: ConditionKind.tradesVsMax),
      const StrategyCondition(kind: ConditionKind.dailyLossVsLimit),
      const StrategyCondition(kind: ConditionKind.newsBuffer),
      const StrategyCondition(kind: ConditionKind.rangeBreak),
      const StrategyCondition(kind: ConditionKind.rangeBreak, closeBack: true),
    ];
    return [
      for (final c in all)
        if (!_conditions.contains(c)) c,
    ];
  }
}

class _PropFields extends StatefulWidget {
  const _PropFields({required this.prop, required this.onChanged});

  final PropRules prop;
  final ValueChanged<PropRules> onChanged;

  @override
  State<_PropFields> createState() => _PropFieldsState();
}

class _PropFieldsState extends State<_PropFields> {
  late final _firm = TextEditingController(text: widget.prop.firm ?? '');
  late final _daily = TextEditingController(
    text: _AccountEditorScreenState._fmt(widget.prop.dailyLossLimitPct),
  );
  late final _dd = TextEditingController(text: _AccountEditorScreenState._fmt(widget.prop.maxDrawdownPct));
  late final _target = TextEditingController(
    text: _AccountEditorScreenState._fmt(widget.prop.profitTargetPct),
  );

  @override
  void dispose() {
    for (final c in [_firm, _daily, _dd, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim());

  void _changed() {
    final firm = _firm.text.trim();
    widget.onChanged(
      widget.prop.copyWith(
        firm: firm.isEmpty ? null : firm,
        dailyLossLimitPct: _num(_daily),
        maxDrawdownPct: _num(_dd),
        profitTargetPct: _num(_target),
      ),
    );
  }

  Widget _pct(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DojiTextField(
      controller: c,
      hint: '$label, %',
      semanticLabel: '$label in percent',
      large: false,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => _changed(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.prop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DojiTextField(
            controller: _firm,
            hint: 'firm (optional)',
            semanticLabel: 'prop firm',
            large: false,
            onChanged: (_) => _changed(),
          ),
        ),
        _pct('daily loss limit', _daily),
        _pct('max drawdown', _dd),
        const _Label('DRAWDOWN'),
        _Chips(
          options: const {DrawdownType.fixed: 'static', DrawdownType.trailing: 'trailing'},
          selected: p.drawdownType,
          onTap: (t) => widget.onChanged(p.copyWith(drawdownType: t)),
        ),
        if (p.drawdownType == DrawdownType.trailing) ...[
          const SizedBox(height: 12),
          const _Label('TRAILS THE HIGHEST'),
          _Chips(
            options: const {TrailingBasis.equity: 'equity', TrailingBasis.balance: 'balance'},
            selected: p.trailingBasis,
            onTap: (b) => widget.onChanged(p.copyWith(trailingBasis: b)),
          ),
        ],
        const SizedBox(height: 12),
        _pct('challenge target', _target),
      ],
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.only(left: 16, right: 4),
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.chip),
      border: Border.all(color: DojiColors.separator),
    ),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(label, style: DojiType.body.copyWith(fontSize: 15)),
          ),
        ),
        DojiIconButton(
          icon: Icons.close_rounded,
          semanticLabel: 'remove $label',
          outlined: false,
          background: Colors.transparent,
          foreground: DojiColors.textSecondary,
          onPressed: onRemove,
        ),
      ],
    ),
  );
}

class _Chips<T> extends StatelessWidget {
  const _Chips({required this.options, required this.selected, required this.onTap, this.mono = false});

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final e in options.entries)
        DojiChoiceChip(
          label: e.value,
          selected: e.key == selected,
          exclusive: true,
          mono: mono,
          style: DojiChoiceStyle.chip,
          minHeight: 44,
          onTap: () => onTap(e.key),
        ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, style: DojiType.label),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(header: true, child: Text(text, style: DojiType.title)),
  );
}
