import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../auth/data/todo_auth_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/onboarding_catalog.dart';

/// Where the intro hands over:
/// - signed in, or finished onboarding on this device → Home placeholder
/// - onboarding paused on "save your setup" → the save screen
/// - otherwise → onboarding (the controller resumes at the saved step, or boot)
String decideLaunchRoute({
  required bool signedIn,
  required bool profileComplete,
  required String? pausedAtStep,
}) {
  if (signedIn || profileComplete) return Routes.home;
  if (pausedAtStep == StepIds.save) return Routes.save;
  return Routes.onboarding;
}

final launchRouteProvider = Provider<String>((ref) {
  final repo = ref.watch(onboardingRepositoryProvider);
  return decideLaunchRoute(
    signedIn: ref.watch(authRepositoryProvider).currentUser != null,
    profileComplete: repo.loadProfile()?.isComplete ?? false,
    pausedAtStep: repo.loadSnapshot()?.currentStepId,
  );
});
