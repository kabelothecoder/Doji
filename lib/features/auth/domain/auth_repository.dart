import 'package:flutter/foundation.dart';

import '../../../core/widgets/auth_method_button.dart' show AuthMethod;
import '../../onboarding/domain/profile_doji.dart';

@immutable
class AuthUser {
  const AuthUser({required this.id, required this.method, this.email, this.name});

  final String id;

  /// How this account signs in (A5 uses it to point back to the right button).
  final AuthMethod method;

  /// Null when Apple hides it and the relay address is not shared.
  final String? email;
  final String? name;

  Map<String, Object?> toJson() => {'id': id, 'method': method.name, 'email': email, 'name': name};

  static AuthUser? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final method = AuthMethod.values.asNameMap()[json['method']];
    if (id is! String || method == null) return null;
    return AuthUser(id: id, method: method, email: json['email'] as String?, name: json['name'] as String?);
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.method == method &&
      other.email == email &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, method, email, name);
}

/// What a sign-in returns: the user, whether the account was just created,
/// and the setup stored on the account (null when it has none yet).
@immutable
class AuthResult {
  const AuthResult({required this.user, required this.isNewAccount, this.remoteProfile});

  final AuthUser user;
  final bool isNewAccount;
  final ProfileDoji? remoteProfile;
}

/// A5: the account an email already belongs to, when it signs in with Apple
/// or Google rather than an email code.
@immutable
class LinkedMethod {
  const LinkedMethod({required this.method, required this.email, this.lastUsedAt});

  final AuthMethod method;
  final String email;
  final DateTime? lastUsedAt;
}

/// A sent email code. Handoff A4: "Codes last 10 minutes", resend after 30s.
@immutable
class EmailCodeTicket {
  const EmailCodeTicket({
    required this.email,
    required this.sentAt,
    required this.expiresAt,
    required this.resendAt,
  });

  final String email;
  final DateTime sentAt;
  final DateTime expiresAt;
  final DateTime resendAt;

  static const lifetime = Duration(minutes: 10);
  static const resendAfter = Duration(seconds: 30);
}

/// Every auth failure the UI has a screen or line for. [message] is shown as
/// a doji terminal line, so it is lowercase and says what still works.
sealed class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The user closed the Apple / Google sheet or the browser. Handoff A2b:
/// "cancel returns to the previous screen with no error".
final class AuthCancelled extends AuthFailure {
  const AuthCancelled() : super('');
}

/// Any call that failed on the network. Shows A10.
final class AuthOffline extends AuthFailure {
  const AuthOffline() : super('connection lost. try again.');
}

/// A4b: "Attempts left are stated plainly."
final class CodeMismatch extends AuthFailure {
  const CodeMismatch(this.attemptsLeft)
    : super("that code didn't match. $attemptsLeft ${attemptsLeft == 1 ? 'try' : 'tries'} left.");

  final int attemptsLeft;
}

/// A4c: the field locks; the only action is a new code.
final class CodeExpired extends AuthFailure {
  const CodeExpired() : super('that code expired. codes last 10 minutes.');
}

/// A4d: "After 5 wrong codes, a 15-minute lock with a live countdown."
final class CodeLocked extends AuthFailure {
  const CodeLocked(this.until) : super('too many attempts.');

  final DateTime until;
}

/// Anything else, already phrased for the user.
final class AuthUnavailable extends AuthFailure {
  const AuthUnavailable(super.message);
}

/// Sign-in and account (design/handoff/Doji Sign-in iOS.dc.html): Apple
/// first, then Google, then a passwordless 6-digit email code.
///
/// Platform channels the real implementation must use (decided 2026-10-07):
/// - iOS: Apple and Google natively, email code.
/// - Android: Google via Credential Manager, Apple via web OAuth, email code.
/// - Windows: Apple and Google via system-browser OAuth with a deep-link
///   return, email code.
abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Opens the system sheet (iOS) or the browser (Android Apple, Windows).
  /// Throws [AuthCancelled] when the user backs out.
  Future<AuthResult> signInWithApple();
  Future<AuthResult> signInWithGoogle();

  /// Stops waiting for a browser sign-in that the user abandoned.
  void cancelSignIn();

  /// A5: non-null when [email] belongs to an Apple or Google account, so the
  /// email code is not sent and that method is offered instead.
  Future<LinkedMethod?> lookUpEmail(String email);

  Future<EmailCodeTicket> sendEmailCode(String email);
  Future<AuthResult> verifyEmailCode({required String email, required String code});

  /// Replaces the setup stored on the account.
  Future<void> uploadProfile(ProfileDoji profile);

  Future<void> signOut();

  /// A12: erases the account and revokes the Sign in with Apple token.
  Future<void> deleteAccount();
}

/// "Send is disabled until the value looks like an email."
bool looksLikeEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());
