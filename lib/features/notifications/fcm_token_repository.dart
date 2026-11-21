import 'package:firebase_database/firebase_database.dart';

class FcmTokenRepository {
  FcmTokenRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  Future<String> saveToken({required String uid, required String token}) async {
    final userTokens = _database.ref('fcm_tokens/$uid');
    final existing = await userTokens
        .orderByChild('token')
        .equalTo(token)
        .get();

    final value = existing.value;
    if (value is Map && value.isNotEmpty) {
      final tokenId = value.keys.first.toString();
      await userTokens.child(tokenId).update({
        'updated_at': ServerValue.timestamp,
      });
      return tokenId;
    }

    final reference = userTokens.push();
    final tokenId = reference.key;
    if (tokenId == null) {
      throw StateError('Gagal membuat ID token FCM.');
    }
    await reference.set({'token': token, 'updated_at': ServerValue.timestamp});
    return tokenId;
  }

  Future<void> removeToken({required String uid, required String tokenId}) {
    return _database.ref('fcm_tokens/$uid/$tokenId').remove();
  }
}
