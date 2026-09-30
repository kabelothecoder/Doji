import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';

/// Placeholder until the auth slice lands. Nobody is ever signed in, and every
/// method explains itself in doji's voice instead of failing silently.
///
/// TODO(next-slice): SupabaseAuthRepository
/// - Apple: sign_in_with_apple → supabase.auth.signInWithIdToken(provider: apple)
/// - Google: google_sign_in (Credential Manager on Android) → signInWithIdToken
/// - Email: supabase.auth.signInWithOtp(email) → verifyOTP(type: email)
/// - on first sign-in, upsert profiles.profile_doji from the local profile and
///   clear pendingSync (see supabase/migrations/0001_profiles.sql)
class TodoAuthRepository implements AuthRepository {
  const TodoAuthRepository();

  static const _soon = 'arrives in the next build. your setup stays on this device.';

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AuthUser> signInWithApple() async => throw const AuthUnavailable('apple sign-in $_soon');

  @override
  Future<AuthUser> signInWithGoogle() async => throw const AuthUnavailable('google sign-in $_soon');

  @override
  Future<void> sendEmailCode(String email) async => throw const AuthUnavailable('email codes $_soon');

  @override
  Future<AuthUser> verifyEmailCode({required String email, required String code}) async =>
      throw const AuthUnavailable('email codes $_soon');

  @override
  Future<void> signOut() async {}
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => const TodoAuthRepository());
