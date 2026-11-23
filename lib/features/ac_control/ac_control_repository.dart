import 'ac_acknowledgement.dart';
import 'ac_action.dart';

abstract interface class AcControlRepository {
  Future<String> sendCommand({
    required AcAction action,
    double? setpoint,
    bool? enabled,
  });

  Stream<AcAcknowledgement?> watchAcknowledgement(String commandId);
}
