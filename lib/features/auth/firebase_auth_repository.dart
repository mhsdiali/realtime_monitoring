import 'package:firebase_auth/firebase_auth.dart';

import 'auth_failure.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, this.onBeforeSignOut})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final Future<void> Function()? onBeforeSignOut;

  @override
  Stream<bool> get signedInChanges =>
      _auth.authStateChanges().map((user) => user != null);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(authFailureMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    await onBeforeSignOut?.call();
    await _auth.signOut();
  }
}

String authFailureMessage(FirebaseAuthException error) {
  if (error.message?.contains('CONFIGURATION_NOT_FOUND') ?? false) {
    return 'Login email belum diaktifkan di Firebase.';
  }
  return switch (error.code) {
    'invalid-email' => 'Format email tidak valid.',
    'user-disabled' => 'Akun ini dinonaktifkan.',
    'network-request-failed' =>
      'Tidak dapat terhubung ke jaringan. Periksa koneksi Anda.',
    'too-many-requests' =>
      'Terlalu banyak percobaan masuk. Silakan coba lagi nanti.',
    'operation-not-allowed' ||
    'configuration-not-found' => 'Login email belum diaktifkan di Firebase.',
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' => 'Email atau kata sandi salah.',
    _ => 'Gagal masuk. Silakan coba lagi.',
  };
}
