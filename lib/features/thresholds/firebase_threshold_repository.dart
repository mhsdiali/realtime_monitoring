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
    final value = snapshot.value;
    if (value is! Map) {
      return null;
    }

    final temperature = value['temperature'];
    final humidity = value['humidity'];
    if (temperature is! Map || humidity is! Map) {
      return null;
    }

    final temperatureMin = (temperature['min'] as num?)?.toDouble();
    final temperatureMax = (temperature['max'] as num?)?.toDouble();
    final humidityMin = (humidity['min'] as num?)?.toDouble();
    final humidityMax = (humidity['max'] as num?)?.toDouble();
    if (temperatureMin == null ||
        temperatureMax == null ||
        humidityMin == null ||
        humidityMax == null) {
      return null;
    }

    return Thresholds(
      temperatureMin: temperatureMin,
      temperatureMax: temperatureMax,
      humidityMin: humidityMin,
      humidityMax: humidityMax,
    );
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
