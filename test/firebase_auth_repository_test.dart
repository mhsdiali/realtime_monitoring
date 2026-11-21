import 'package:app_monitoring/features/auth/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pesan kredensial salah tidak membocorkan status email', () {
    expect(
      authFailureMessage(FirebaseAuthException(code: 'wrong-password')),
      'Email atau kata sandi salah.',
    );
    expect(
      authFailureMessage(FirebaseAuthException(code: 'user-not-found')),
      'Email atau kata sandi salah.',
    );
    expect(
      authFailureMessage(FirebaseAuthException(code: 'invalid-credential')),
      'Email atau kata sandi salah.',
    );
  });

  test('memetakan galat lain ke pesan Indonesia', () {
    expect(
      authFailureMessage(FirebaseAuthException(code: 'invalid-email')),
      'Format email tidak valid.',
    );
    expect(
      authFailureMessage(FirebaseAuthException(code: 'network-request-failed')),
      contains('jaringan'),
    );
    expect(
      authFailureMessage(
        FirebaseAuthException(
          code: 'internal-error',
          message:
              'An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]',
        ),
      ),
      'Login email belum diaktifkan di Firebase.',
    );
    expect(
      authFailureMessage(FirebaseAuthException(code: 'tidak-dikenal')),
      'Gagal masuk. Silakan coba lagi.',
    );
  });
}
