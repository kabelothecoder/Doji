import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/onboarding/domain/availability.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no fit without both answers or with an undecided style', () {
    expect(availabilityFit(null, 'scalper'), isNull);
    expect(availabilityFit('not_flexible', null), isNull);
    expect(availabilityFit('not_flexible', 'undecided'), isNull);
  });

  test('screen-bound styles do not fit a busy week', () {
    expect(availabilityFit('not_flexible', 'day_trader')!.fits, isFalse);
    expect(availabilityFit('not_flexible', 'swing,scalper')!.line, contains('scalping'));
    expect(availabilityFit('semi_flexible', 'scalper')!.fits, isFalse);
  });

  test('fitting combinations', () {
    expect(availabilityFit('not_flexible', 'swing')!.fits, isTrue);
    expect(availabilityFit('semi_flexible', 'day_trader')!.fits, isTrue);
    expect(availabilityFit('fully_flexible', 'scalper')!.fits, isTrue);
  });

  test('every line and option keeps the copy rules', () {
    const styles = ['scalper', 'day_trader', 'swing'];
    for (final o in availabilityOptions) {
      expect(breaksCopyRules('${o.label} ${o.sub}'), isFalse);
      for (final s in styles) {
        final line = availabilityFit(o.value, s)!.line;
        expect(breaksCopyRules(line), isFalse, reason: line);
      }
    }
  });

  test('onboarding stores the answer on the profile', () {
    final p = profileFromAnswers({StepIds.availability: 'semi_flexible'});
    expect(p.availability, 'semi_flexible');
  });
}
