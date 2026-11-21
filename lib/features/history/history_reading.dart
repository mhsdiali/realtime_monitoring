class HistoryReading {
  const HistoryReading({
    required this.temperature,
    required this.humidity,
    required this.timestampMillis,
  });

  final double temperature;
  final double humidity;
  final int timestampMillis;
}
