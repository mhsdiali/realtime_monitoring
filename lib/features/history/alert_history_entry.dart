class AlertHistoryEntry {
  const AlertHistoryEntry({
    required this.status,
    required this.activeParameters,
    required this.temperature,
    required this.humidity,
    required this.timestampMillis,
    this.readingTimestampMillis,
  });

  final String status;
  final List<String> activeParameters;
  final double temperature;
  final double humidity;
  final int timestampMillis;
  final int? readingTimestampMillis;
}
