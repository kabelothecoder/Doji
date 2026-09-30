import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

/// Thrown by methods that aren't wired yet (this slice) or can't run offline.
/// [message] is shown to the user as a doji terminal line.
class AuthUnavailable implements Exception {
  const AuthUnavailable(this.message);

  final String message;

  @override
  String toString() => 'AuthUnavailable: $message';
}

/// Sign-in for the next slice: Apple first, then Google, then a passwordless
/// 6-digit email code (design/handoff/Doji Sign-in iOS.dc.html).
abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> authStateChanges();

  Future<AuthUser> signInWithApple();
  Future<AuthUser> signInWithGoogle();
  Future<void> sendEmailCode(String email);
  Future<AuthUser> verifyEmailCode({required String email, required String code});
  Future<void> signOut();
}
