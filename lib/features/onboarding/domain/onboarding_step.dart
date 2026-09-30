import 'package:flutter/foundation.dart';

/// Answers keyed by step id. Values are JSON-safe (String, num, bool, List,
/// Map) so the whole map persists as-is after every answer.
typedef Answers = Map<String, Object?>;

/// How a step collects its answer (brief: single | multi | text | voiceOrText
/// | stepper | slider | time | info | custom).
enum StepInput { single, multi, text, voiceOrText, stepper, slider, time, info, custom }

/// Which screen layout renders the step.
enum StepView {
  /// Terminal boot lines + "hey. i'm doji."
  boot,

  /// "There is no holy grail. There is balance."
  manifesto,

  /// The conversation shell: reply, typed question, input, footer.
  question,

  /// `> compiling profile.doji…` → profile card.
  compile,

  /// Hold to pledge.
  pledge,

  /// Hand-off to the auth stub (SaveYourSetupScreen).
  save,
}

@immutable
class StepOption {
  const StepOption(this.value, this.label, {this.sub, this.mono = false});

  /// Stored in answers and profile.doji (snake_case).
  final String value;

  /// Shown on the chip (handoff copy).
  final String label;
  final String? sub;

  /// Symbols and numbers render in Geist Mono.
  final bool mono;
}

/// One step of the data-driven onboarding engine.
///
/// The engine never special-cases ids: visibility comes from [condition],
/// replies from [reply], validation from [validate]. Presentation picks a
/// widget from [view] and [input].
@immutable
class OnboardingStep {
  const OnboardingStep({
    required this.id,
    required this.view,
    required this.input,
    this.prompt = '',
    this.sub,
    this.options = const [],
    this.optionsFor,
    this.validate,
    this.skippable = true,
    this.reply,
    this.condition,
    this.cta = 'continue',
    this.skipLabel = 'skip for now',
    this.columns = 2,
    this.showConfig = true,
    this.configWindow = 3,
    this.autoAdvance = false,
    this.countsAsAnswer = true,
  });

  final String id;
  final StepView view;
  final StepInput input;

  /// Doji's typed line.
  final String prompt;

  /// Grey line under the prompt ("pick any.").
  final String? sub;
  final List<StepOption> options;

  /// Options that depend on earlier answers (e.g. ritual times).
  final List<StepOption> Function(Answers answers)? optionsFor;

  /// Returns doji's error line, or null when the answer is fine.
  final String? Function(Object? answer)? validate;
  final bool skippable;

  /// Doji's short, personal reply to this step's answer. It is shown above
  /// the *next* step's question ("sam. good to meet you.").
  final String? Function(Object? answer, Answers answers)? reply;

  /// Show this step only when true (e.g. review parsed strategy only if
  /// there is a strategy to review).
  final bool Function(Answers answers)? condition;
  final String cta;
  final String skipLabel;
  final int columns;

  /// Whether the compact profile.doji card shows on this step.
  final bool showConfig;

  /// Config rows visible in the compact card (crowded steps use 1).
  final int configWindow;

  /// Single choice: advance 350ms after a tap.
  final bool autoAdvance;

  /// Info steps (boot, manifesto, compile) don't count as answers.
  final bool countsAsAnswer;

  bool isVisible(Answers answers) => condition?.call(answers) ?? true;

  List<StepOption> resolveOptions(Answers answers) => optionsFor?.call(answers) ?? options;
}

/// Typed readers for JSON-decoded answers (ints may come back as num, lists
/// as `List<dynamic>`).
abstract final class A {
  static String? str(Answers a, String key) {
    final v = a[key];
    return v is String && v.trim().isNotEmpty ? v : null;
  }

  static List<String> list(Answers a, String key) {
    final v = a[key];
    return v is List ? v.whereType<String>().toList() : const [];
  }

  static Map<String, Object?> map(Answers a, String key) {
    final v = a[key];
    return v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : const {};
  }

  static String? mapStr(Object? m, String key) {
    if (m is! Map) return null;
    final v = m[key];
    return v is String && v.trim().isNotEmpty ? v : null;
  }

  static double? mapNum(Object? m, String key) {
    if (m is! Map) return null;
    final v = m[key];
    return v is num ? v.toDouble() : null;
  }
}
