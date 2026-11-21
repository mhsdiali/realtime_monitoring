abstract interface class AuthRepository {
  Stream<bool> get signedInChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
