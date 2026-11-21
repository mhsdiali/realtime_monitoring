import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'device_status.dart';
import 'latest_reading.dart';
import 'monitoring_repository.dart';
import 'monitoring_snapshot.dart';

class FirebaseMonitoringRepository implements MonitoringRepository {
  FirebaseMonitoringRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  @override
  Stream<MonitoringSnapshot> watchDashboard() {
    late final StreamController<MonitoringSnapshot> controller;
    final subscriptions = <StreamSubscription<DatabaseEvent>>[];
    Timer? timer;
    LatestReading? reading;
    int? lastSeen;
    int serverOffset = 0;

    void emit() {
      if (controller.isClosed) {
        return;
      }
      final nowMillis = DateTime.now().millisecondsSinceEpoch + serverOffset;
      controller.add(
        MonitoringSnapshot(
          reading: reading,
          isOnline: isDeviceOnline(
            lastSeenMillis: lastSeen,
            nowMillis: nowMillis,
          ),
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
        timer = Timer.periodic(const Duration(seconds: 5), (_) => emit());
        emit();
      },
      onCancel: () {
        timer?.cancel();
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
