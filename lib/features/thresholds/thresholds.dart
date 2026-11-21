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
}
