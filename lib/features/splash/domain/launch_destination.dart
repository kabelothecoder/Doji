import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/onboarding_catalog.dart';

/// Where the intro hands over:
/// - a finished profile.doji on this device → Home placeholder (signing in
///   always stores the account's setup locally, so this covers signed-in users)
/// - onboarding paused on "save your setup" → the save screen
/// - otherwise → onboarding (the controller resumes at the saved step, or
///   boot). A signed-in account without a setup lands here too.
String decideLaunchRoute({required bool profileComplete, required String? pausedAtStep}) {
  if (profileComplete) return Routes.home;
  if (pausedAtStep == StepIds.save) return Routes.save;
  return Routes.onboarding;
}

/// Read once by the intro. Auto-disposed so sign out and delete, which wipe
/// local data, are seen by the next launch decision.
final launchRouteProvider = Provider.autoDispose<String>((ref) {
  final repo = ref.watch(onboardingRepositoryProvider);
  return decideLaunchRoute(
    profileComplete: repo.loadProfile()?.isComplete ?? false,
    pausedAtStep: repo.loadSnapshot()?.currentStepId,
  );
});
