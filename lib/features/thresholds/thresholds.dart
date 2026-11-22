class Thresholds {
  const Thresholds({
    required this.temperatureMin,
    required this.temperatureMax,
    required this.humidityMin,
    required this.humidityMax,
  });

  static const defaults = Thresholds(
    temperatureMin: 16,
    temperatureMax: 20,
    humidityMin: 40,
    humidityMax: 60,
  );

  final double temperatureMin;
  final double temperatureMax;
  final double humidityMin;
  final double humidityMax;

  /// Membaca node `thresholds` dari RTDB. Null bila node belum lengkap.
  static Thresholds? fromValue(Object? value) {
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
}
