import 'package:clock/clock.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/widgets/auth_method_button.dart' show AuthMethod;
import '../../onboarding/domain/profile_doji.dart';
import '../domain/auth_repository.dart';

/// Real sign-in with Supabase Auth: the 6-digit email code (A3/A4). The
/// session is what the `mt5` edge function checks, so broker links and live
/// MT5 prices need it.
///
/// Apple and Google are not wired yet (each needs its own native or OAuth
/// setup, see [AuthRepository]); they answer with a line pointing to email.
/// The Supabase email template must send `{{ .Token }}` for a code instead of
/// a magic link.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  static const maxAttempts = 5;
  static const lockFor = Duration(minutes: 15);
  final _wrong = <String, int>{};
  final _lockedUntil = <String, DateTime>{};

  @override
  AuthUser? get currentUser {
    final u = _client.auth.currentUser;
    if (u == null) return null;
    return AuthUser(id: u.id, method: AuthMethod.email, email: u.email);
  }

  static const _notYet = AuthUnavailable('apple and google sign-in come later. use your email for now.');

  @override
  Future<AuthResult> signInWithApple() async => throw _notYet;

  @override
  Future<AuthResult> signInWithGoogle() async => throw _notYet;

  @override
  void cancelSignIn() {}

  String _key(String email) => email.trim().toLowerCase();

  void _checkLock(String key) {
    final until = _lockedUntil[key];
    if (until == null) return;
    if (clock.now().isBefore(until)) throw CodeLocked(until);
    _lockedUntil.remove(key);
    _wrong.remove(key);
  }

  // TODO(backend): look the email up (an edge function over auth.identities)
  // once Apple and Google sign-in exist; until then every account is email.
  @override
  Future<LinkedMethod?> lookUpEmail(String email) async => null;

  @override
  Future<EmailCodeTicket> sendEmailCode(String email) async {
    if (!looksLikeEmail(email)) throw const AuthUnavailable("that doesn't look like an email.");
    _checkLock(_key(email));
    try {
      await _client.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true);
    } on AuthException catch (e) {
      throw _map(e);
    } on Object {
      throw const AuthOffline();
    }
    final now = clock.now();
    return EmailCodeTicket(
      email: email.trim(),
      sentAt: now,
      expiresAt: now.add(EmailCodeTicket.lifetime),
      resendAt: now.add(EmailCodeTicket.resendAfter),
    );
  }

  @override
  Future<AuthResult> verifyEmailCode({required String email, required String code}) async {
    final key = _key(email);
    _checkLock(key);
    final AuthResponse res;
    try {
      res = await _client.auth.verifyOTP(email: email.trim(), token: code, type: OtpType.email);
    } on AuthException catch (e) {
      if (e.code == 'otp_expired' && e.message.toLowerCase().contains('expired')) throw const CodeExpired();
      final wrong = (_wrong[key] ?? 0) + 1;
      _wrong[key] = wrong;
      if (wrong >= maxAttempts) {
        final until = clock.now().add(lockFor);
        _lockedUntil[key] = until;
        throw CodeLocked(until);
      }
      throw CodeMismatch(maxAttempts - wrong);
    } on Object {
      throw const AuthOffline();
    }
    _wrong.remove(key);
    final u = res.user;
    if (u == null) throw const AuthUnavailable('sign-in did not finish. try again.');
    final user = AuthUser(id: u.id, method: AuthMethod.email, email: u.email);
    ProfileDoji? remote;
    try {
      final row = await _client.from('profiles').select('profile_doji').eq('id', u.id).maybeSingle();
      final json = row?['profile_doji'];
      if (json is Map<String, dynamic> && json.isNotEmpty) remote = ProfileDoji.fromJson(json);
    } on Object {
      remote = null;
    }
    return AuthResult(user: user, isNewAccount: remote == null, remoteProfile: remote);
  }

  @override
  Future<void> uploadProfile(ProfileDoji profile) async {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthUnavailable('sign in first.');
    try {
      await _client.from('profiles').upsert({
        'id': u.id,
        'profile_doji': profile.copyWith(pendingSync: false).toJson(),
        'onboarding_version': profile.onboardingVersion,
      });
    } on Object {
      throw const AuthOffline();
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  /// shortcut: removes the profile row (broker links are unlinked first by
  /// `AccountActions`, which also drops their Vault passwords). Erasing the
  /// auth user itself needs the service role: add a `delete-account` edge
  /// function before public release.
  @override
  Future<void> deleteAccount() async {
    final u = _client.auth.currentUser;
    if (u != null) {
      try {
        await _client.from('profiles').delete().eq('id', u.id);
      } on Object {
        throw const AuthOffline();
      }
    }
    await _client.auth.signOut();
  }

  AuthFailure _map(AuthException e) => switch (e.statusCode) {
    '429' => const AuthUnavailable('too many codes asked for. wait a minute and try again.'),
    _ => AuthUnavailable(e.message.toLowerCase()),
  };
}
