import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../accounts/data/broker_link_repository.dart';
import '../../accounts/domain/trading_account.dart';
import '../../../core/widgets/auth_method_button.dart' show AuthMethod;
import '../../app_lock/presentation/app_lock_controller.dart';
import '../../chart/data/chart_note_repository.dart';
import '../../coach/data/coach_session_repository.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../markets/data/brief_allowance_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../../plans/data/billing_repository.dart';
import '../../plans/presentation/plans_controller.dart';
import '../data/fake_auth_repository.dart';
import '../domain/auth_repository.dart';

/// Where the flow started: A1 "welcome back" or A2 "save your setup".
enum AuthIntent { signIn, save }

enum CodeStatus { idle, verifying, wrong, expired, locked }

/// What A9 / A9b print, and where they hand off.
@immutable
class AuthOutcome {
  const AuthOutcome({required this.statusLines, required this.destination, this.welcomeName});

  /// "verifying code… ok", "loading profile.doji… 14 lines".
  final List<String> statusLines;

  /// "welcome back, [Name]." Null for new accounts: "the name was just entered".
  final String? welcomeName;

  /// Routes.home, or Routes.onboarding when the account has no setup yet.
  final String destination;
}

@immutable
class AuthFlowState {
  const AuthFlowState({
    this.intent = AuthIntent.signIn,
    this.waitingFor,
    this.offline = false,
    this.message,
    this.email = '',
    this.ticket,
    this.sending = false,
    this.codeStatus = CodeStatus.idle,
    this.attemptsLeft = FakeAuthRepository.maxAttempts,
    this.lockedUntil,
    this.outcome,
  });

  final AuthIntent intent;

  /// Apple or Google sheet open (A2b).
  final AuthMethod? waitingFor;

  /// A10.
  final bool offline;

  /// Tilt line for anything else that went wrong.
  final String? message;

  final String email;
  final EmailCodeTicket? ticket;
  final bool sending;
  final CodeStatus codeStatus;
  final int attemptsLeft;
  final DateTime? lockedUntil;
  final AuthOutcome? outcome;

  bool get busy => waitingFor != null || sending || codeStatus == CodeStatus.verifying;

  AuthFlowState copyWith({
    AuthIntent? intent,
    AuthMethod? Function()? waitingFor,
    bool? offline,
    String? Function()? message,
    String? email,
    EmailCodeTicket? Function()? ticket,
    bool? sending,
    CodeStatus? codeStatus,
    int? attemptsLeft,
    DateTime? Function()? lockedUntil,
    AuthOutcome? Function()? outcome,
  }) => AuthFlowState(
    intent: intent ?? this.intent,
    waitingFor: waitingFor == null ? this.waitingFor : waitingFor(),
    offline: offline ?? this.offline,
    message: message == null ? this.message : message(),
    email: email ?? this.email,
    ticket: ticket == null ? this.ticket : ticket(),
    sending: sending ?? this.sending,
    codeStatus: codeStatus ?? this.codeStatus,
    attemptsLeft: attemptsLeft ?? this.attemptsLeft,
    lockedUntil: lockedUntil == null ? this.lockedUntil : lockedUntil(),
    outcome: outcome == null ? this.outcome : outcome(),
  );
}

/// The signed-in user, for settings and launch.
class AuthSession extends Notifier<AuthUser?> {
  @override
  AuthUser? build() => ref.watch(authRepositoryProvider).currentUser;

  void set(AuthUser? user) => state = user;
}

final authSessionProvider = NotifierProvider<AuthSession, AuthUser?>(AuthSession.new);

/// Drives A1 → A2b / A3 → A4 → A9 and A10. Screens only render this state and
/// navigate on the returned booleans.
class AuthFlowController extends Notifier<AuthFlowState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  OnboardingRepository get _local => ref.read(onboardingRepositoryProvider);

  @override
  AuthFlowState build() => const AuthFlowState();

  // --- Apple / Google (A2b) ------------------------------------------------------

  Future<bool> signInWith(AuthMethod method, AuthIntent intent) async {
    assert(method != AuthMethod.email, 'email goes through sendCode');
    state = AuthFlowState(intent: intent, waitingFor: method);
    try {
      final result = method == AuthMethod.apple
          ? await _repo.signInWithApple()
          : await _repo.signInWithGoogle();
      // waitingFor stays set: the screen navigates away on true, and clearing
      // it would flash the (now reset) entry screen for a frame.
      await _complete(result, intent);
      return true;
    } on AuthFailure catch (e) {
      _fail(e);
      return false;
    }
  }

  void cancelSheet() {
    _repo.cancelSignIn();
    state = state.copyWith(waitingFor: () => null);
  }

  // --- Email code (A3 / A4) ------------------------------------------------------

  void setEmail(String v) => state = state.copyWith(email: v, message: () => null);

  /// Sends (or resends) a code. A new code invalidates the previous one.
  Future<bool> sendCode(AuthIntent intent) async {
    final email = state.email.trim();
    if (!looksLikeEmail(email) || state.sending) return false;
    state = state.copyWith(intent: intent, sending: true, offline: false, message: () => null);
    try {
      final ticket = await _repo.sendEmailCode(email);
      state = state.copyWith(
        sending: false,
        ticket: () => ticket,
        codeStatus: CodeStatus.idle,
        lockedUntil: () => null,
      );
      return true;
    } on AuthFailure catch (e) {
      _fail(e);
      return false;
    }
  }

  /// Any keystroke after a wrong code clears the orange state.
  void codeEdited() {
    if (state.codeStatus == CodeStatus.wrong) state = state.copyWith(codeStatus: CodeStatus.idle);
  }

  Future<bool> verify(String code) async {
    if (state.codeStatus == CodeStatus.verifying || state.codeStatus == CodeStatus.locked) return false;
    final intent = state.intent;
    state = state.copyWith(codeStatus: CodeStatus.verifying, offline: false, message: () => null);
    try {
      final result = await _repo.verifyEmailCode(email: state.email.trim(), code: code);
      await _complete(result, intent);
      state = state.copyWith(codeStatus: CodeStatus.idle);
      return true;
    } on AuthFailure catch (e) {
      _fail(e);
      return false;
    }
  }

  // --- Already signed in ------------------------------------------------------------

  /// Reaching "save your setup" while signed in (an account that had no
  /// setup yet): no buttons needed, the setup goes straight to the account.
  Future<bool> saveToSignedInAccount() async {
    final user = ref.read(authSessionProvider);
    if (user == null || state.sending) return false;
    state = const AuthFlowState(intent: AuthIntent.save, sending: true);
    try {
      await _complete(
        AuthResult(user: user, isNewAccount: false),
        AuthIntent.save,
        firstLine: 'signed in… ok',
      );
      return true;
    } on AuthFailure catch (e) {
      _fail(e);
      return false;
    }
  }

  // --- A10 -----------------------------------------------------------------------

  /// "continue offline is available only when a local setup exists."
  bool get canContinueOffline => state.intent == AuthIntent.save
      ? ref.read(onboardingControllerProvider).profile.pledgedAt != null
      : _local.loadProfile()?.isComplete ?? false;

  /// Keeps the setup on this device (same as "continue without account").
  Future<void> continueOffline() async {
    if (state.intent == AuthIntent.save) {
      await ref.read(onboardingControllerProvider.notifier).finishLocally();
    }
    state = state.copyWith(offline: false);
  }

  // --- internals -----------------------------------------------------------------

  void _fail(AuthFailure e) {
    switch (e) {
      case AuthCancelled():
        state = state.copyWith(waitingFor: () => null, sending: false, codeStatus: CodeStatus.idle);
      case AuthOffline():
        state = state.copyWith(
          offline: true,
          waitingFor: () => null,
          sending: false,
          codeStatus: CodeStatus.idle,
        );
      case CodeMismatch(:final attemptsLeft):
        state = state.copyWith(codeStatus: CodeStatus.wrong, attemptsLeft: attemptsLeft, sending: false);
      case CodeExpired():
        state = state.copyWith(codeStatus: CodeStatus.expired, sending: false);
      case CodeLocked(:final until):
        state = state.copyWith(codeStatus: CodeStatus.locked, lockedUntil: () => until, sending: false);
      case AuthUnavailable(:final message):
        state = state.copyWith(
          message: () => message,
          waitingFor: () => null,
          sending: false,
          codeStatus: CodeStatus.idle,
        );
    }
  }

  /// Decides which setup this device keeps, then writes the outcome.
  ///
  /// - save (A2): this device's setup goes to the account. If the account had
  ///   its own, this device still wins: A6's default ("it is the most
  ///   recent"), applied silently until A6 is built.
  /// - sign in (A1): the account's setup wins and replaces this device's.
  ///   An account with none adopts this device's finished setup, if any.
  Future<void> _complete(AuthResult r, AuthIntent intent, {String? firstLine}) async {
    final verified = switch (r.user.method) {
      AuthMethod.email => 'verifying code… ok',
      AuthMethod.apple => 'verifying apple id… ok',
      AuthMethod.google => 'verifying google account… ok',
    };
    final first = firstLine ?? (r.isNewAccount ? 'creating account… ok' : verified);
    final onboarding = ref.read(onboardingControllerProvider.notifier);

    late final String second;
    late final String destination;
    String? name;
    if (intent == AuthIntent.save) {
      final lines = ref.read(onboardingControllerProvider).configLines.length;
      final profile = await onboarding.finishLocally();
      await _upload(profile);
      second = 'saving profile.doji… $lines lines';
      // New setup: plans come right after "save your setup".
      destination = Routes.plans;
    } else if (r.remoteProfile case final remote?) {
      await _local.saveProfile(remote.copyWith(pendingSync: false));
      await _local.clearSnapshot();
      second = 'loading profile.doji… ok';
      destination = remote.isComplete ? Routes.home : Routes.onboarding;
      name = remote.name;
    } else if (_local.loadProfile() case final local? when local.isComplete) {
      await _upload(local);
      second = 'saving profile.doji… ok';
      destination = Routes.home;
      name = local.name;
    } else {
      second = 'no profile.doji on this account yet';
      destination = Routes.onboarding;
    }

    ref.read(authSessionProvider.notifier).set(r.user);
    ref.invalidate(onboardingControllerProvider);
    state = state.copyWith(
      outcome: () => AuthOutcome(
        statusLines: [first, second],
        destination: destination,
        welcomeName: r.isNewAccount || intent == AuthIntent.save ? null : (name ?? ''),
      ),
    );
  }

  Future<void> _upload(ProfileDoji profile) async {
    await _repo.uploadProfile(profile);
    await _local.saveProfile(profile.copyWith(pendingSync: false));
  }
}

final authFlowProvider = NotifierProvider<AuthFlowController, AuthFlowState>(AuthFlowController.new);

/// Sign out and delete both end with this device forgetting the user:
/// profile.doji, any paused onboarding, the journal, app lock, and the session.
class AccountActions {
  AccountActions(this._ref);

  final Ref _ref;

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
    await _wipeLocal();
  }

  /// Throws [AuthFailure] (usually [AuthOffline]); nothing local is touched
  /// unless the account is really gone.
  Future<void> deleteAccount() async {
    // Broker links first, while the session still exists: their MT5
    // passwords leave Supabase Vault with them.
    final links = _ref.read(brokerLinkRepositoryProvider);
    if (links.available) {
      for (final a
          in _ref.read(onboardingRepositoryProvider).loadProfile()?.accounts ?? const <TradingAccount>[]) {
        if (a.brokerLink != null) await links.unlink(a.id);
      }
    }
    await _ref.read(authRepositoryProvider).deleteAccount();
    await _wipeLocal();
  }

  Future<void> _wipeLocal() async {
    await _ref.read(onboardingRepositoryProvider).clearAll();
    // The journal is this device's copy of the trades: it goes with the profile.
    await _ref.read(journalRepositoryProvider).clear();
    _ref.invalidate(journalControllerProvider);
    // Saved coach sessions ("coaching history" on the delete screen) too.
    await _ref.read(coachSessionRepositoryProvider).clear();
    await _ref.read(chartNoteRepositoryProvider).clear();
    _ref.invalidate(chartNotesProvider);
    await _ref.read(briefAllowanceRepositoryProvider).clear();
    await _ref.read(brokerLinkRepositoryProvider).clear();
    await _ref.read(appLockControllerProvider.notifier).reset();
    await _ref.read(billingRepositoryProvider).clear();
    _ref.invalidate(entitlementProvider);
    _ref.read(authSessionProvider.notifier).set(null);
    _ref.invalidate(onboardingControllerProvider);
    _ref.invalidate(authFlowProvider);
  }
}

final accountActionsProvider = Provider<AccountActions>(AccountActions.new);

/// Seconds left until [until], for "resend in 0:30" and the lock countdown.
Duration remaining(DateTime? until) {
  if (until == null) return Duration.zero;
  final d = until.difference(clock.now());
  return d.isNegative ? Duration.zero : d;
}

/// 0:30, 14:59.
String mmss(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
