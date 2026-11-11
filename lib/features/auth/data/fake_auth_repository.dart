import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/platform/connectivity.dart';
import '../../../core/widgets/auth_method_button.dart' show AuthMethod;
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../markets/data/mt5_api.dart' show supabaseClientProvider;
import '../domain/auth_repository.dart';
import 'supabase_auth_repository.dart';

/// A working, on-device stand-in for the auth backend. It behaves like the
/// handoff prototype so every screen can be built and tested before Supabase:
///
/// - Apple / Google: a [sheetLatency] wait, then a fixed sample identity.
/// - Email: any 6 digits sign in, except
///   - `111111` → wrong code (5 tries, then a 15-minute lock)
///   - `000000` → expired code
/// - Accounts and their profile.doji live in shared_preferences, so sign out
///   and sign back in really does bring the setup back.
/// - Offline (per [isOnline]) every call throws [AuthOffline].
///
/// Swap for `SupabaseAuthRepository` in [authRepositoryProvider]; the UI only
/// sees [AuthRepository].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(
    this._prefs, {
    bool Function()? isOnline,
    this.sheetLatency = const Duration(milliseconds: 1600),
    this.networkLatency = const Duration(milliseconds: 600),
  }) : _isOnline = isOnline ?? (() => true);

  final SharedPreferences _prefs;
  final bool Function() _isOnline;
  final Duration sheetLatency;
  final Duration networkLatency;

  static const sessionKey = 'doji.auth.session.v1';
  static const accountsKey = 'doji.auth.fake_accounts.v1';

  static const wrongCode = '111111';
  static const expiredCode = '000000';
  static const maxAttempts = 5;
  static const lockFor = Duration(minutes: 15);

  final _tickets = <String, EmailCodeTicket>{};
  final _wrong = <String, int>{};
  final _lockedUntil = <String, DateTime>{};
  Completer<void>? _sheet;

  // --- session -----------------------------------------------------------------

  @override
  AuthUser? get currentUser {
    final raw = _prefs.getString(sessionKey);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> _setSession(AuthUser? user) =>
      user == null ? _prefs.remove(sessionKey) : _prefs.setString(sessionKey, jsonEncode(user.toJson()));

  // --- accounts ----------------------------------------------------------------

  Map<String, Object?> _accounts() {
    final raw = _prefs.getString(accountsKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } on Object {
      return {};
    }
  }

  Future<void> _saveAccounts(Map<String, Object?> a) => _prefs.setString(accountsKey, jsonEncode(a));

  Future<AuthResult> _signIn(AuthUser user) async {
    final accounts = _accounts();
    final existing = accounts[user.id];
    final isNew = existing is! Map;
    ProfileDoji? remote;
    if (existing is Map && existing['profile'] is Map) {
      try {
        remote = ProfileDoji.fromJson((existing['profile'] as Map).cast<String, dynamic>());
      } on Object {
        remote = null;
      }
    }
    accounts[user.id] = {
      if (existing is Map) ...existing.cast<String, Object?>() else 'profile': null,
      'method': user.method.name,
      'email': user.email,
      'lastUsedAt': clock.now().toUtc().toIso8601String(),
    };
    await _saveAccounts(accounts);
    await _setSession(user);
    return AuthResult(user: user, isNewAccount: isNew, remoteProfile: remote);
  }

  void _requireOnline() {
    if (!_isOnline()) throw const AuthOffline();
  }

  // --- Apple / Google ------------------------------------------------------------

  Future<void> _waitForSheet() async {
    _requireOnline();
    final sheet = _sheet = Completer<void>();
    final timer = Timer(sheetLatency, () {
      if (!sheet.isCompleted) sheet.complete();
    });
    try {
      await sheet.future;
    } finally {
      timer.cancel();
      if (identical(_sheet, sheet)) _sheet = null;
    }
  }

  @override
  void cancelSignIn() {
    final sheet = _sheet;
    if (sheet != null && !sheet.isCompleted) sheet.completeError(const AuthCancelled());
  }

  @override
  Future<AuthResult> signInWithApple() async {
    await _waitForSheet();
    return _signIn(
      const AuthUser(id: 'apple:sample', method: AuthMethod.apple, email: 'apple.user@example.com'),
    );
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    await _waitForSheet();
    return _signIn(
      const AuthUser(id: 'google:sample', method: AuthMethod.google, email: 'google.user@example.com'),
    );
  }

  // --- email code ----------------------------------------------------------------

  String _key(String email) => email.trim().toLowerCase();

  void _checkLock(String key) {
    final until = _lockedUntil[key];
    if (until == null) return;
    if (clock.now().isBefore(until)) throw CodeLocked(until);
    _lockedUntil.remove(key);
    _wrong.remove(key);
  }

  /// An email with `+apple` or `+google` before the `@` (e.g.
  /// `me+google@example.com`) answers as that method, so A5 can be tried
  /// without a stored account; otherwise the stored Apple / Google accounts.
  @override
  Future<LinkedMethod?> lookUpEmail(String email) async {
    _requireOnline();
    final key = _key(email);
    for (final m in [AuthMethod.apple, AuthMethod.google]) {
      if (key.contains('+${m.name}@')) return LinkedMethod(method: m, email: email.trim());
    }
    for (final a in _accounts().values) {
      if (a is! Map || (a['email'] as String?)?.toLowerCase() != key) continue;
      final m = AuthMethod.values.asNameMap()[a['method']];
      if (m == null || m == AuthMethod.email) continue;
      return LinkedMethod(
        method: m,
        email: email.trim(),
        lastUsedAt: DateTime.tryParse(a['lastUsedAt'] as String? ?? ''),
      );
    }
    return null;
  }

  @override
  Future<EmailCodeTicket> sendEmailCode(String email) async {
    _requireOnline();
    if (!looksLikeEmail(email)) throw const AuthUnavailable("that doesn't look like an email.");
    final key = _key(email);
    _checkLock(key);
    await Future<void>.delayed(networkLatency);
    final now = clock.now();
    // A new ticket invalidates the previous code.
    return _tickets[key] = EmailCodeTicket(
      email: email.trim(),
      sentAt: now,
      expiresAt: now.add(EmailCodeTicket.lifetime),
      resendAt: now.add(EmailCodeTicket.resendAfter),
    );
  }

  @override
  Future<AuthResult> verifyEmailCode({required String email, required String code}) async {
    _requireOnline();
    final key = _key(email);
    _checkLock(key);
    await Future<void>.delayed(networkLatency);
    final ticket = _tickets[key];
    if (ticket == null || code == expiredCode || clock.now().isAfter(ticket.expiresAt)) {
      throw const CodeExpired();
    }
    if (code == wrongCode || !RegExp(r'^\d{6}$').hasMatch(code)) {
      final wrong = (_wrong[key] ?? 0) + 1;
      _wrong[key] = wrong;
      if (wrong >= maxAttempts) {
        final until = clock.now().add(lockFor);
        _lockedUntil[key] = until;
        throw CodeLocked(until);
      }
      throw CodeMismatch(maxAttempts - wrong);
    }
    _tickets.remove(key);
    _wrong.remove(key);
    return _signIn(AuthUser(id: 'email:$key', method: AuthMethod.email, email: ticket.email));
  }

  // --- account -------------------------------------------------------------------

  @override
  Future<void> uploadProfile(ProfileDoji profile) async {
    _requireOnline();
    final user = currentUser;
    if (user == null) throw const AuthUnavailable('sign in first.');
    final accounts = _accounts();
    final account = (accounts[user.id] as Map?)?.cast<String, Object?>() ?? {'method': user.method.name};
    accounts[user.id] = {...account, 'profile': profile.copyWith(pendingSync: false).toJson()};
    await _saveAccounts(accounts);
  }

  @override
  Future<void> signOut() => _setSession(null);

  @override
  Future<void> deleteAccount() async {
    _requireOnline();
    final user = currentUser;
    if (user != null) {
      await Future<void>.delayed(networkLatency);
      final accounts = _accounts()..remove(user.id);
      await _saveAccounts(accounts);
    }
    await _setSession(null);
  }
}

/// Supabase email-code sign-in when Supabase is configured; this fake
/// otherwise (fully local runs, tests).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client != null) return SupabaseAuthRepository(client);
  return FakeAuthRepository(
    ref.watch(sharedPreferencesProvider),
    isOnline: () => ref.read(isOnlineProvider).value ?? true,
  );
});
