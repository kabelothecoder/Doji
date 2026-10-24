import '../../markets/domain/time_zones.dart';
import 'onboarding_catalog.dart';
import 'onboarding_step.dart';
import 'profile_doji.dart';

/// The trader's zone from the time-zone answer: the detected IANA id (with
/// daylight saving), or the offset they picked by hand.
UserZone userZoneFromAnswers(Answers answers) {
  final tz = answers[StepIds.timeZone];
  return UserZone.from(id: A.mapStr(tz, 'id'), offsetMinutes: A.mapNum(tz, 'offsetMinutes')?.round());
}

/// The same, from a saved profile.
UserZone userZoneFromProfile(ProfileDoji p) =>
    UserZone.from(id: p.timeZone, offsetMinutes: p.utcOffsetMinutes);
