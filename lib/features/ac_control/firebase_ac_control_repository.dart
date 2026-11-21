import 'package:firebase_database/firebase_database.dart';

import 'ac_acknowledgement.dart';
import 'ac_action.dart';
import 'ac_control_repository.dart';

class FirebaseAcControlRepository implements AcControlRepository {
  FirebaseAcControlRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  @override
  Future<String> sendCommand({
    required AcAction action,
    double? setpoint,
  }) async {
    final reference = _database.ref('devices/ac_control/commands').push();
    final data = <String, Object?>{
      'action': action.value,
      'created_at': ServerValue.timestamp,
    };
    if (setpoint != null) {
      data['setpoint'] = setpoint;
    }

    await reference.set(data);
    final commandId = reference.key;
    if (commandId == null) {
      throw StateError('Gagal membuat ID perintah AC.');
    }
    return commandId;
  }

  @override
  Stream<AcAcknowledgement?> watchAcknowledgement(String commandId) {
    return _database
        .ref('devices/ac_control/acknowledgements/$commandId')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value is! Map) {
            return null;
          }
          final status = value['status'];
          if (status is! String) {
            return null;
          }
          return AcAcknowledgement(
            status: status,
            errorMessage: value['error_message'] as String?,
          );
        });
  }
}
