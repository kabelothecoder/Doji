import 'package:clock/clock.dart';

import '../../../core/widgets/config_panel.dart';
import 'onboarding_catalog.dart';
import 'onboarding_step.dart';
import 'profile_doji.dart';
import 'profile_mapper.dart';
import 'risk.dart';
import 'sessions.dart';
import 'user_zone.dart';

/// One line of profile.doji: which step owns it, whether it applies, and how
/// to print its value.
class _Spec {
  const _Spec(this.key, this.stepId, this.print, {this.applies, this.target});

  final String key;
  final String stepId;
  final _Printed? Function(Answers a, ProfileDoji p) print;
  final bool Function(Answers a)? applies;

  /// Step to open on tap when different from [stepId].
  final String Function(Answers a)? target;
}

typedef _Printed = ({String value, ConfigValueTone tone, String comment});

_Printed _sym(String v, [String comment = '']) => (value: v, tone: ConfigValueTone.symbol, comment: comment);
_Printed _lit(String v, [String comment = '']) => (value: v, tone: ConfigValueTone.literal, comment: comment);

const _experienceShort = {'lt_6m': '<6m', '6_24m': '6-24m', '2_5y': '2-5y', '5y_plus': '5y+'};

String _list(List<String> xs) => '[${xs.join(', ')}]';

/// 50000 → 50_000
String _underscored(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('_');
    b.write(s[i]);
  }
  return b.toString();
}

String _pct1(double v) => '${v.toStringAsFixed(1)}%';

bool _isProp(Answers a) => A.mapStr(a[StepIds.goal], 'goal') == 'prop_challenge';

final List<_Spec> _specs = [
  _Spec('name', StepIds.name, (a, p) => p.name == null ? null : _lit('"${p.name}"')),
  _Spec(
    'experience',
    StepIds.experience,
    (a, p) => p.experience == null ? null : _sym(_experienceShort[p.experience] ?? p.experience!),
  ),
  _Spec('style', StepIds.style, (a, p) => p.style == null ? null : _sym(p.style!)),
  _Spec('markets', StepIds.markets, (a, p) => p.instruments.isEmpty ? null : _sym(_list(p.instruments))),
  _Spec('sessions', StepIds.sessions, (a, p) {
    if (p.sessions.isEmpty) return null;
    // The offset today, so a zone with daylight saving reads right all year.
    final tz = p.utcOffsetMinutes == null
        ? ''
        : '  # ${utcLabel(userZoneFromProfile(p).offsetMinutesAt(clock.now()))}';
    return _sym(_list(p.sessions), tz);
  }),
  _Spec('goal', StepIds.goal, (a, p) => p.goal == null ? null : _sym(p.goal!)),
  _Spec('prop.size', StepIds.goal, (a, p) {
    final firm = p.prop?.firm == null ? '' : '  # ${p.prop!.firm!.toLowerCase()}';
    final size = p.startingSize?.round();
    if (size == null) {
      return (value: 'null', tone: ConfigValueTone.muted, comment: firm.isEmpty ? '  # optional' : firm);
    }
    return _lit(_underscored(size), firm);
  }, applies: _isProp),
  _Spec('prop.limits', StepIds.goal, (a, p) {
    final r = p.prop;
    if (r == null || (r.dailyLossLimitPct == null && r.maxDrawdownPct == null && r.profitTargetPct == null)) {
      return (value: 'null', tone: ConfigValueTone.muted, comment: '  # optional');
    }
    String f(double? v) => v == null ? '-' : _pct1(v);
    return _lit(
      '${f(r.dailyLossLimitPct)} / ${f(r.maxDrawdownPct)} / ${f(r.profitTargetPct)}',
      '  # daily loss / ${r.drawdownLabel} drawdown / target',
    );
  }, applies: _isProp),
  _Spec('struggles', StepIds.struggles, (a, p) => p.struggles.isEmpty ? null : _sym(_list(p.struggles))),
  _Spec(
    'strategy',
    StepIds.strategy,
    (a, p) {
      final s = p.strategy;
      if (s == null) return null;
      final parsed = s.parsed;
      if (parsed != null && !parsed.isEmpty) {
        final tf = parsed.timeframe == null ? '' : '  # ${parsed.timeframe}';
        return _sym(parsed.slug, tf);
      }
      if (s.template == 'none') return (value: 'none_yet', tone: ConfigValueTone.muted, comment: '');
      if (s.template != null) return _sym(s.template!);
      if (s.rawText != null) return _sym('custom', '  # parsing');
      return null;
    },
    target: (a) => a.containsKey(StepIds.strategyParsed) && hasStrategyToReview(a)
        ? StepIds.strategyParsed
        : StepIds.strategy,
  ),
  _Spec('risk', StepIds.risk, (a, p) {
    final r = p.rules?.riskPerTrade;
    return r == null ? null : _lit(_pct1(r), riskNote(r) != null ? '  # above 2%' : '');
  }),
  _Spec('max_trades', StepIds.risk, (a, p) {
    final n = p.rules?.maxTradesPerDay;
    return n == null ? null : _lit('$n');
  }),
  _Spec('daily_loss', StepIds.risk, (a, p) {
    final d = p.rules?.dailyLossLimit;
    return d == null ? null : _lit(_pct1(d));
  }),
  _Spec('coach.voice', StepIds.coach, (a, p) {
    final v = p.coach?.voice;
    return v == null ? null : _sym(v);
  }),
  _Spec('coach.name', StepIds.coach, (a, p) {
    if (p.coach == null) return null;
    return _lit('"${p.coach!.name ?? 'doji'}"');
  }),
  _Spec('ritual', StepIds.ritual, (a, p) {
    final t = p.theOpenTime;
    if (t == null) return null;
    final opts = ritualOptions(a);
    final sub = opts.where((o) => o.value == t).firstOrNull?.sub;
    final session = firstSession(p.sessions, userZoneFromProfile(p))?.label.toLowerCase();
    final when = switch (sub) {
      '30m before' => '30m pre-${session ?? 'session'}',
      '15m before' => '15m pre-${session ?? 'session'}',
      'at the open' => 'at the ${session ?? 'session'} open',
      _ => '',
    };
    return _lit(t, when.isEmpty ? '' : '  # $when');
  }),
];

/// Lines expected once onboarding is done, given the answers so far
/// (prop.size only counts when the goal is a prop challenge).
int totalConfigLines(Answers a) => _specs.where((s) => s.applies?.call(a) ?? true).length;

/// Renders profile.doji. Skipped steps print `null  # skipped`; unanswered
/// steps are omitted. The newest line of [highlightStepId] is tinted green.
List<ConfigLineData> buildConfigLines(Answers a, {Set<String> skipped = const {}, String? highlightStepId}) {
  final p = profileFromAnswersCached(a);
  final out = <ConfigLineData>[];
  for (final spec in _specs) {
    if (!(spec.applies?.call(a) ?? true)) continue;
    final target = spec.target?.call(a) ?? spec.stepId;
    _Printed? printed;
    if (skipped.contains(spec.stepId)) {
      printed = (value: 'null', tone: ConfigValueTone.muted, comment: '  # skipped');
    } else if (a.containsKey(spec.stepId)) {
      printed = spec.print(a, p);
    }
    if (printed == null) continue;
    out.add(
      ConfigLineData(
        number: out.length + 1,
        keyName: spec.key,
        value: printed.value,
        tone: printed.tone,
        comment: printed.comment,
        targetId: target,
      ),
    );
  }
  if (highlightStepId != null) {
    final i = out.lastIndexWhere(
      (l) =>
          l.targetId == highlightStepId ||
          (highlightStepId == StepIds.strategyParsed && l.keyName == 'strategy'),
    );
    if (i >= 0) out[i] = out[i].copyWith(highlighted: true);
  }
  return out;
}

// profileFromAnswers is cheap, but config lines rebuild on every keystroke of
// the text steps; keep the last result.
Answers? _lastAnswers;
ProfileDoji? _lastProfile;

ProfileDoji profileFromAnswersCached(Answers a) {
  if (identical(a, _lastAnswers) && _lastProfile != null) return _lastProfile!;
  _lastAnswers = a;
  return _lastProfile = profileFromAnswers(a);
}
