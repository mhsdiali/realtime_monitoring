import 'package:firebase_database/firebase_database.dart';

import 'threshold_repository.dart';
import 'thresholds.dart';

class FirebaseThresholdRepository implements ThresholdRepository {
  FirebaseThresholdRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  @override
  Future<Thresholds?> loadThresholds() async {
    final snapshot = await _database.ref('thresholds').get();
    return Thresholds.fromValue(snapshot.value);
  }

  @override
  Future<void> saveThresholds(Thresholds thresholds) {
    return _database.ref('thresholds').set({
      'temperature': {
        'min': thresholds.temperatureMin,
        'max': thresholds.temperatureMax,
      },
      'humidity': {
        'min': thresholds.humidityMin,
        'max': thresholds.humidityMax,
      },
    });
  }
}
