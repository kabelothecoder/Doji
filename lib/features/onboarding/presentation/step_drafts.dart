import '../domain/onboarding_catalog.dart';
import '../domain/onboarding_step.dart';

/// The in-progress answer for the step on screen, before "continue".
/// Pure functions so keyboard picking and tests share one code path.

Object? initialDraft(OnboardingStep step, Answers answers) {
  final saved = answers[step.id];
  Map<String, Object?> savedMap() =>
      saved is Map ? saved.map((k, v) => MapEntry(k.toString(), v)) : <String, Object?>{};
  switch (step.id) {
    case StepIds.name:
      return saved is String ? saved : '';
    case StepIds.markets || StepIds.sessions || StepIds.struggles:
      return saved is List ? saved.whereType<String>().toList() : <String>[];
    case StepIds.risk:
      return {'maxTrades': 3, 'dailyLoss': 2.0, ...savedMap()};
    case StepIds.ritual:
      final opts = step.resolveOptions(answers);
      return {'time': opts.first.value, ...savedMap()};
    case StepIds.goal || StepIds.strategy || StepIds.strategyParsed || StepIds.coach:
      return savedMap();
    default:
      return saved;
  }
}

/// Number keys 1–9 on desktop. Returns the new draft, or null if [index] is
/// out of range for this step.
Object? pickOption(OnboardingStep step, Answers answers, Object? draft, int index) {
  final options = step.resolveOptions(answers);
  if (index < 0 || index >= options.length) return null;
  final value = options[index].value;
  Map<String, Object?> asMap() => draft is Map ? Map<String, Object?>.from(draft) : {};
  switch (step.id) {
    case StepIds.markets || StepIds.sessions || StepIds.struggles:
      final list = draft is List ? List<String>.from(draft) : <String>[];
      return list.contains(value) ? (list..remove(value)) : (list..add(value));
    case StepIds.goal:
      return {...asMap(), 'goal': value};
    case StepIds.risk:
      final pct = double.tryParse(value);
      final m = asMap();
      return pct == null
          ? {...m, 'custom': true, 'riskPct': A.mapNum(m, 'riskPct') ?? 3.0}
          : {...m, 'custom': false, 'riskPct': pct};
    case StepIds.coach:
      return {...asMap(), 'voice': value};
    case StepIds.ritual:
      return {...asMap(), 'time': value};
    default:
      return step.input == StepInput.single ? value : null;
  }
}
