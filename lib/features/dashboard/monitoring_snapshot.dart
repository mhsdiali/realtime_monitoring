import 'latest_reading.dart';

class MonitoringSnapshot {
  const MonitoringSnapshot({this.reading, required this.isOnline});

  final LatestReading? reading;
  final bool isOnline;
}
