import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:doji_app/features/onboarding/domain/strategy_files.dart';
import 'package:doji_app/features/plans/domain/plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('style', () {
    test('reads the new list and the old single answer', () {
      expect(styleFromAnswer(['scalper', 'day_trader']), 'scalper,day_trader');
      expect(styleFromAnswer('swing'), 'swing');
      expect(styleFromAnswer(const <String>[]), isNull);
      expect(styleReply(['scalper', 'swing'], {}), 'scalper and swing. noted.');
    });
  });

  group('strategy files', () {
    test('kinds and limits', () {
      expect(strategyFileKind('plan.PDF'), StrategyFileKind.pdf);
      expect(strategyFileKind('chart.jpg'), StrategyFileKind.image);
      expect(strategyFileKind('walk.mov'), StrategyFileKind.video);
      expect(strategyFileProblem('notes.docx', 10), isNotNull);
      expect(strategyFileProblem('walk.mp4', kMaxVideoBytes + 1), isNotNull);
      expect(strategyFileProblem('walk.mp4', kMaxVideoBytes), isNull);
    });

    test('a file alone is a valid strategy answer', () {
      final step = buildOnboardingSteps().firstWhere((s) => s.id == StepIds.strategy);
      expect(
        step.validate!({
          'files': [
            {'name': 'a.pdf', 'kind': 'pdf'},
          ],
        }),
        isNull,
      );
      expect(step.validate!(<String, Object?>{}), isNotNull);
    });
  });

  group('risk profile', () {
    test('answers map onto the profile', () {
      final p = profileFromAnswers({
        StepIds.risk: {'riskPct': 1, 'appetite': 'careful', 'deposit': '500_5k'},
      });
      expect(p.riskAppetite, 'careful');
      expect(p.usualDeposit, '500_5k');
    });

    test('recommendPlan for each appetite and funding', () {
      for (final a in ['careful', 'balanced', 'aggressive']) {
        for (final d in ['lt_500', '500_5k', '5k_25k', '25k_plus']) {
          final want = a == 'aggressive' || d == '25k_plus' ? PlanId.pro : PlanId.basic;
          expect(
            recommendPlan(ProfileDoji(riskAppetite: a, usualDeposit: d)),
            want,
            reason: '$a $d',
          );
          expect(
            recommendPlan(ProfileDoji(goal: 'prop_challenge', riskAppetite: a, usualDeposit: d)),
            PlanId.elite,
          );
        }
      }
    });

    test('new copy keeps the copy rules', () {
      final lines = [
        for (final o in appetiteOptions) ...[o.label, ?o.sub],
        for (final o in depositOptions) o.label,
        strategyFileProblem('x.doc', 0)!,
        strategyFileProblem('x.mp4', kMaxVideoBytes + 1)!,
      ];
      for (final l in lines) {
        expect(breaksCopyRules(l), isFalse, reason: l);
      }
    });
  });
}
