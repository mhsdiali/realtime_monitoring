import 'thresholds.dart';

abstract interface class ThresholdRepository {
  Future<Thresholds?> loadThresholds();

  Future<void> saveThresholds(Thresholds thresholds);
}
