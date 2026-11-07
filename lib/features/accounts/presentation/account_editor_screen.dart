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
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/onboarding_catalog.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/prop_rules.dart';
import '../../onboarding/data/mock_strategy_parser.dart';
import '../../onboarding/domain/sessions.dart';
import '../../onboarding/domain/strategy_parser.dart';
import '../../onboarding/presentation/steps/step_input.dart';
import '../../onboarding/presentation/steps/text_inputs.dart';
import '../data/strategy_reader.dart';
import '../domain/condition_eval.dart';
import '../domain/trading_account.dart';
import 'accounts_controller.dart';
import 'broker_link_section.dart';

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

  /// The strategy as stored, to tell whether its words changed. Read in
  /// initState: a lazy initialiser would see the edited draft.
  late StrategyProfile? _savedStrategy;
  static final _strategyStep = buildOnboardingSteps().firstWhere((s) => s.id == StepIds.strategy);
  bool _dirty = false;
  bool _saving = false;

  /// Set when the parser failed on save: the words are saved, not read.
  bool _parseFailed = false;

  /// "read my words": what doji proposed, until the trader accepts or drops it.
  StrategyProposal? _proposal;
  bool _reading = false;

  /// Set when the starting size cannot be used; save stays off until fixed.
  String? _sizeError;

  /// The first edit to a text field rebuilds, so the back guard sees it.
  void _touched() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Empty = no size; otherwise a number above zero.
  String? _checkSize(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return v == null || v <= 0 ? 'enter a size above zero, or leave it empty.' : null;
  }

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

  @override
  void initState() {
    super.initState();
    _savedStrategy = _draft?.strategy;
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

  /// Linking happens at once, apart from save: store the link on the saved
  /// account and on the draft, without marking the draft dirty.
  Future<void> _linkChanged(BrokerLink? link) async {
    final stored = ref
        .read(accountsControllerProvider)
        .accounts
        .where((x) => x.id == widget.accountId)
        .firstOrNull;
    if (stored != null) {
      await ref.read(accountsControllerProvider.notifier).save(stored.copyWith(brokerLink: link));
    }
    if (mounted) setState(() => _draft = _draft!.copyWith(brokerLink: link));
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.accounts);

  Future<void> _save() async {
    final sizeError = _checkSize(_size.text);
    if (sizeError != null) {
      setState(() => _sizeError = sizeError);
      return;
    }
    setState(() => _saving = true);
    final name = _name.text.trim();
    final rules = _rules;
    var strategy = _strategy;
    var failed = false;
    // New words are read again, as onboarding does, so MEASURED AGAINST and the
    // brief follow them. The conditions stay as the trader set them.
    if (strategy.rawText != _savedStrategy?.rawText || strategy.template != _savedStrategy?.template) {
      final raw = strategy.rawText;
      ParsedStrategy? parsed;
      if (raw != null) {
        try {
          parsed = await ref.read(strategyParserProvider).parse(raw);
        } on Object {
          parsed = null; // parser failed: no parsed setup rather than a stale one
          failed = true;
        }
      } else if (strategy.template != null && strategy.template != 'none') {
        parsed = strategyTemplates[strategy.template];
      }
      if (!mounted) return;
      strategy = strategy.copyWith(parsed: parsed);
    }
    final account = _draft!.copyWith(
      name: name.isEmpty ? _draft!.kind.label : name,
      startingSize: double.tryParse(_size.text.trim()),
      // What the steppers show is what gets measured.
      rules: rules.copyWith(
        riskPerTrade: rules.riskPerTrade ?? 1,
        maxTradesPerDay: rules.maxTradesPerDay ?? 3,
        dailyLossLimit: rules.dailyLossLimit ?? 2,
      ),
      strategy: strategy,
    );
    await ref.read(accountsControllerProvider.notifier).save(account);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
      _parseFailed = failed;
      _savedStrategy = strategy;
    });
    // Stay so the trader sees it: the words are kept, doji just could not read them.
    if (!failed) _back();
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
        actions: [
          if (_parseFailed) ...[
            const TerminalLine("couldn't read your strategy, saved your words.", tone: TerminalTone.tilt),
            const SizedBox(height: 12),
          ],
          DojiButton(
            label: _saving ? 'saving' : 'save',
            onPressed: _saving || _sizeError != null ? null : () => unawaited(_save()),
          ),
        ],
        body: [
          Semantics(header: true, child: Text('edit account', style: DojiType.largeTitle)),
          const SizedBox(height: 20),
          const _Label('NAME'),
          DojiTextField(
            controller: _name,
            hint: a.kind.label,
            semanticLabel: 'account name',
            large: false,
            onChanged: (_) => _touched(),
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
            helper: _sizeError ?? 'loss % and the prop drawdown are measured against it.',
            hasError: _sizeError != null,
            semanticLabel: 'starting size in ${a.accountCurrency}',
            large: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (v) {
              _touched();
              final error = _checkSize(v);
              if (error != _sizeError) setState(() => _sizeError = error);
            },
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
          const _Section('broker'),
          BrokerLinkSection(account: a, onChanged: _linkChanged),
          const SizedBox(height: 28),
          KeyedSubtree(key: _strategyKey, child: const _Section('strategy')),
          Text('in your own words. say it or type it.', style: DojiType.callout),
          const SizedBox(height: 12),
          StrategyInput(
            StepInputArgs(
              step: _strategyStep,
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
            parsing: _saving,
          ),
          const SizedBox(height: 12),
          DojiButton(
            label: _reading ? 'reading your words…' : 'read my words',
            variant: DojiButtonVariant.secondary,
            onPressed: _reading || (_strategy.rawText?.trim().isEmpty ?? true)
                ? null
                : () => unawaited(_read()),
          ),
          if (_proposal case final p?) ...[
            const SizedBox(height: 12),
            _ProposalCard(
              proposal: p,
              onUse: () => _useProposal(replace: true),
              onAdd: () => _useProposal(replace: false),
              onDrop: () => setState(() => _proposal = null),
            ),
          ],
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
              onUp: i == 0 ? null : () => _move(i, i - 1),
              onDown: i == _conditions.length - 1 ? null : () => _move(i, i + 1),
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

  Future<void> _read() async {
    final words = _strategy.rawText?.trim() ?? '';
    if (words.isEmpty || _reading) return;
    setState(() => _reading = true);
    final sessions = ref.read(onboardingRepositoryProvider).loadProfile()?.sessions ?? const <String>[];
    StrategyProposal? p;
    try {
      p = await ref.read(strategyReaderProvider).propose(words, sessions: sessions);
    } on Object {
      p = null;
    }
    if (!mounted) return;
    setState(() {
      _reading = false;
      _proposal = p;
    });
  }

  /// Accept: the proposal replaces the list (still editable, saved with "save").
  void _useProposal({required bool replace}) {
    final p = _proposal!;
    final next = replace
        ? p.conditions
        : [..._conditions, ...p.conditions.where((c) => !_conditions.contains(c))];
    _edit((a) => a.copyWith(strategy: _strategy.copyWith(conditions: next)));
    setState(() => _proposal = null);
  }

  /// Order matters: the brief lists conditions as the trader orders them.
  void _move(int from, int to) {
    final next = [..._conditions];
    final c = next.removeAt(from);
    next.insert(to, c);
    _setConditions(next);
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

/// What doji read from the trader's words: the conditions it would measure,
/// with the trader's own rules marked "check on your chart". Nothing changes
/// until the trader picks one of the three.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onUse,
    required this.onAdd,
    required this.onDrop,
  });

  final StrategyProposal proposal;
  final VoidCallback onUse;
  final VoidCallback onAdd;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      border: Border.all(color: DojiColors.separator),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('DOJI READ YOUR WORDS AS'),
        if (proposal.conditions.isEmpty)
          Text("doji couldn't find a rule it can measure. add your own below.", style: DojiType.callout)
        else
          for (final c in proposal.conditions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('· ${conditionLabel(c)}', style: DojiType.body.copyWith(fontSize: 15)),
            ),
        const SizedBox(height: 12),
        if (proposal.conditions.isNotEmpty) ...[
          DojiButton(label: 'use these', onPressed: onUse),
          const SizedBox(height: 8),
          DojiButton(label: 'add to mine', variant: DojiButtonVariant.secondary, onPressed: onAdd),
          const SizedBox(height: 8),
        ],
        DojiButton(label: 'keep mine', variant: DojiButtonVariant.text, onPressed: onDrop),
      ],
    ),
  );
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.label, required this.onRemove, this.onUp, this.onDown});

  final String label;
  final VoidCallback onRemove;

  /// Null at the top / bottom of the list.
  final VoidCallback? onUp;
  final VoidCallback? onDown;

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
        for (final (icon, word, onTap) in [
          (Icons.keyboard_arrow_up_rounded, 'up', onUp),
          (Icons.keyboard_arrow_down_rounded, 'down', onDown),
        ])
          // Hidden at the ends rather than greyed: an off button that still takes a
          // tap is noise for a screen reader.
          if (onTap != null)
            DojiIconButton(
              icon: icon,
              semanticLabel: 'move $label $word',
              outlined: false,
              background: Colors.transparent,
              foreground: DojiColors.textSecondary,
              onPressed: onTap,
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
