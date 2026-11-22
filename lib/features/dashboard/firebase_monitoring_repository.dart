import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../thresholds/thresholds.dart';
import 'alert_state.dart';
import 'device_status.dart';
import 'latest_reading.dart';
import 'monitoring_repository.dart';
import 'monitoring_snapshot.dart';

/// Koneksi dianggap putus hanya bila terputus lebih lama dari ini, supaya
/// banner tidak berkedip saat aplikasi baru dibuka atau jaringan berganti.
const _disconnectGrace = Duration(seconds: 4);

class FirebaseMonitoringRepository implements MonitoringRepository {
  FirebaseMonitoringRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  @override
  Stream<MonitoringSnapshot> watchDashboard() {
    late final StreamController<MonitoringSnapshot> controller;
    final subscriptions = <StreamSubscription<DatabaseEvent>>[];
    Timer? timer;
    Timer? graceTimer;
    LatestReading? reading;
    AlertState? alert;
    Thresholds? thresholds;
    int? lastSeen;
    int serverOffset = 0;
    var connected = true;
    DateTime? disconnectedSince;

    void emit() {
      if (controller.isClosed) {
        return;
      }
      final nowMillis = DateTime.now().millisecondsSinceEpoch + serverOffset;
      final since = disconnectedSince;
      final isConnected =
          connected ||
          (since != null && DateTime.now().difference(since) < _disconnectGrace);
      controller.add(
        MonitoringSnapshot(
          reading: reading,
          isOnline: isDeviceOnline(
            lastSeenMillis: lastSeen,
            nowMillis: nowMillis,
          ),
          alert: alert,
          thresholds: thresholds,
          isConnected: isConnected,
        ),
      );
    }

    void listen(String path, void Function(Object? value) onValue) {
      subscriptions.add(
        _database
            .ref(path)
            .onValue
            .listen(
              (event) => onValue(event.snapshot.value),
              onError: (Object error, StackTrace stackTrace) {
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            ),
      );
    }

    controller = StreamController<MonitoringSnapshot>(
      onListen: () {
        listen('monitoring/latest', (value) {
          reading = _parseReading(value);
          emit();
        });
        listen('devices/status/last_seen', (value) {
          lastSeen = (value as num?)?.toInt();
          emit();
        });
        listen('.info/serverTimeOffset', (value) {
          serverOffset = (value as num?)?.toInt() ?? 0;
          emit();
        });
        listen('alert_state', (value) {
          alert = AlertState.fromValue(value);
          emit();
        });
        listen('thresholds', (value) {
          thresholds = Thresholds.fromValue(value);
          emit();
        });
        listen('.info/connected', (value) {
          final nowConnected = value == true;
          graceTimer?.cancel();
          if (nowConnected) {
            disconnectedSince = null;
          } else if (connected || disconnectedSince == null) {
            disconnectedSince = DateTime.now();
            graceTimer = Timer(_disconnectGrace, emit);
          }
          connected = nowConnected;
          emit();
        });
        timer = Timer.periodic(const Duration(seconds: 5), (_) => emit());
        emit();
      },
      onCancel: () {
        timer?.cancel();
        graceTimer?.cancel();
        for (final subscription in subscriptions) {
          subscription.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  LatestReading? _parseReading(Object? value) {
    if (value is! Map) {
      return null;
    }

    final temperature = (value['temperature'] as num?)?.toDouble();
    final humidity = (value['humidity'] as num?)?.toDouble();
    final timestamp = (value['timestamp'] as num?)?.toInt();
    if (temperature == null || humidity == null || timestamp == null) {
      return null;
    }

    return LatestReading(
      temperature: temperature,
      humidity: humidity,
      timestampMillis: timestamp,
    );
  }
}
