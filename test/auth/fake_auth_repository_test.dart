import 'package:clock/clock.dart';
import 'package:doji_app/core/widgets/auth_method_button.dart';
import 'package:doji_app/features/auth/data/fake_auth_repository.dart';
import 'package:doji_app/features/auth/domain/auth_repository.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  var online = true;

  FakeAuthRepository repo({Duration sheet = Duration.zero}) =>
      FakeAuthRepository(prefs, isOnline: () => online, sheetLatency: sheet, networkLatency: Duration.zero);

  setUp(() async {
    online = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('email code', () {
    test('any 6 digits sign in and the session survives a restart', () async {
      final r = repo();
      await r.sendEmailCode('Sam@Example.com ');
      final result = await r.verifyEmailCode(email: 'sam@example.com', code: '482913');
      expect(result.isNewAccount, isTrue);
      expect(result.user.method, AuthMethod.email);
      expect(result.user.email, 'Sam@Example.com');
      expect(repo().currentUser, result.user);
    });

    test('wrong codes count down, then a 15-minute lock', () async {
      final r = repo();
      await r.sendEmailCode('sam@example.com');
      for (final left in [4, 3, 2, 1]) {
        await expectLater(
          r.verifyEmailCode(email: 'sam@example.com', code: FakeAuthRepository.wrongCode),
          throwsA(isA<CodeMismatch>().having((e) => e.attemptsLeft, 'attemptsLeft', left)),
        );
      }
      await expectLater(
        r.verifyEmailCode(email: 'sam@example.com', code: FakeAuthRepository.wrongCode),
        throwsA(isA<CodeLocked>()),
      );
      // Locked: no new code either, and the right code doesn't help.
      await expectLater(r.sendEmailCode('sam@example.com'), throwsA(isA<CodeLocked>()));

      // 15 minutes later the lock lifts.
      await withClock(Clock.fixed(DateTime.now().add(const Duration(minutes: 16))), () async {
        await r.sendEmailCode('sam@example.com');
        final ok = await r.verifyEmailCode(email: 'sam@example.com', code: '123456');
        expect(ok.user.email, 'sam@example.com');
      });
    });

    test('codes expire after 10 minutes', () async {
      final r = repo();
      await r.sendEmailCode('sam@example.com');
      await withClock(Clock.fixed(DateTime.now().add(const Duration(minutes: 11))), () async {
        await expectLater(
          r.verifyEmailCode(email: 'sam@example.com', code: '123456'),
          throwsA(isA<CodeExpired>()),
        );
      });
      await expectLater(
        r.verifyEmailCode(email: 'sam@example.com', code: FakeAuthRepository.expiredCode),
        throwsA(isA<CodeExpired>()),
      );
    });

    test('resend is allowed after 30 seconds and restarts the timer', () async {
      final r = repo();
      final first = await r.sendEmailCode('sam@example.com');
      expect(first.resendAt.difference(first.sentAt), EmailCodeTicket.resendAfter);
      expect(first.expiresAt.difference(first.sentAt), EmailCodeTicket.lifetime);
    });

    test('rejects things that are not emails', () async {
      await expectLater(repo().sendEmailCode('sam@'), throwsA(isA<AuthUnavailable>()));
      expect(looksLikeEmail('sam@example.com'), isTrue);
      expect(looksLikeEmail(' sam@example.com '), isTrue);
      expect(looksLikeEmail('sam@example'), isFalse);
      expect(looksLikeEmail('sam example@x.io'), isFalse);
    });
  });

  group('apple / google', () {
    test('cancel returns AuthCancelled, not an error', () async {
      final r = repo(sheet: const Duration(seconds: 5));
      final pending = r.signInWithApple();
      r.cancelSignIn();
      await expectLater(pending, throwsA(isA<AuthCancelled>()));
      expect(r.currentUser, isNull);
    });

    test('a second sign-in finds the setup saved by the first', () async {
      final r = repo();
      final first = await r.signInWithGoogle();
      expect(first.isNewAccount, isTrue);
      expect(first.remoteProfile, isNull);
      await r.uploadProfile(const ProfileDoji(name: 'sam', pendingSync: true));
      await r.signOut();
      expect(r.currentUser, isNull);

      final again = await repo().signInWithGoogle();
      expect(again.isNewAccount, isFalse);
      expect(again.remoteProfile?.name, 'sam');
      expect(again.remoteProfile?.pendingSync, isFalse);
    });
  });

  test('offline: every call says so', () async {
    online = false;
    final r = repo();
    await expectLater(r.signInWithApple(), throwsA(isA<AuthOffline>()));
    await expectLater(r.sendEmailCode('sam@example.com'), throwsA(isA<AuthOffline>()));
    await expectLater(
      r.verifyEmailCode(email: 'sam@example.com', code: '123456'),
      throwsA(isA<AuthOffline>()),
    );
  });

  test('delete erases the account; signing in again starts fresh', () async {
    final r = repo();
    await r.signInWithApple();
    await r.uploadProfile(const ProfileDoji(name: 'sam'));
    await r.deleteAccount();
    expect(r.currentUser, isNull);
    final again = await r.signInWithApple();
    expect(again.isNewAccount, isTrue);
    expect(again.remoteProfile, isNull);
  });
}
