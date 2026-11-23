import 'package:firebase_database/firebase_database.dart';

import 'alert_history_entry.dart';
import 'history_reading.dart';
import 'history_repository.dart';

class FirebaseHistoryRepository implements HistoryRepository {
  FirebaseHistoryRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  @override
  Future<List<HistoryReading>> fetchHistory({required int fromMillis}) async {
    final snapshot = await _database
        .ref('monitoring/history')
        .orderByKey()
        .startAt('$fromMillis')
        .limitToLast(500)
        .get();

    final readings = <HistoryReading>[];
    for (final child in snapshot.children) {
      final value = child.value;
      if (value is! Map) {
        continue;
      }

      final temperature = (value['temperature'] as num?)?.toDouble();
      final humidity = (value['humidity'] as num?)?.toDouble();
      final timestamp = (value['timestamp'] as num?)?.toInt();
      if (temperature == null || humidity == null || timestamp == null) {
        continue;
      }

      readings.add(
        HistoryReading(
          temperature: temperature,
          humidity: humidity,
          timestampMillis: timestamp,
        ),
      );
    }

    readings.sort(
      (first, second) =>
          first.timestampMillis.compareTo(second.timestampMillis),
    );
    return readings;
  }

  @override
  Future<List<AlertHistoryEntry>> fetchAlertHistory({int limit = 5}) async {
    final snapshot = await _database
        .ref('alert_history')
        .orderByChild('timestamp')
        .limitToLast(limit)
        .get();

    final entries = <AlertHistoryEntry>[];
    for (final child in snapshot.children) {
      final value = child.value;
      if (value is! Map) {
        continue;
      }
      if (value['status'] != 'abnormal') {
        continue;
      }

      final temperature = (value['temperature'] as num?)?.toDouble();
      final humidity = (value['humidity'] as num?)?.toDouble();
      final timestamp = (value['timestamp'] as num?)?.toInt();
      if (temperature == null || humidity == null || timestamp == null) {
        continue;
      }

      final rawParameters = value['active_parameters'];
      final activeParameters = <String>[
        if (rawParameters is List)
          for (final parameter in rawParameters)
            if (parameter is String) parameter,
      ];

      entries.add(
        AlertHistoryEntry(
          status: 'abnormal',
          activeParameters: activeParameters,
          temperature: temperature,
          humidity: humidity,
          timestampMillis: timestamp,
          readingTimestampMillis: (value['reading_timestamp'] as num?)?.toInt(),
        ),
      );
    }

    entries.sort(
      (first, second) =>
          second.timestampMillis.compareTo(first.timestampMillis),
    );
    return entries.take(limit).toList();
  }
}
