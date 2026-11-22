import '../thresholds/thresholds.dart';
import 'alert_state.dart';
import 'latest_reading.dart';

class MonitoringSnapshot {
  const MonitoringSnapshot({
    this.reading,
    required this.isOnline,
    this.alert,
    this.thresholds,
    this.isConnected = true,
  });

  final LatestReading? reading;

  /// Perangkat ESP32 mengirim data dalam 30 detik terakhir.
  final bool isOnline;

  /// Null bila worker belum pernah mengevaluasi kondisi.
  final AlertState? alert;

  /// Null bila batas normal belum disimpan petugas.
  final Thresholds? thresholds;

  /// Aplikasi terhubung ke Firebase Realtime Database.
  final bool isConnected;
}
