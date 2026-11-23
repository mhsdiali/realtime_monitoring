import 'alert_history_entry.dart';
import 'history_reading.dart';

abstract interface class HistoryRepository {
  Future<List<HistoryReading>> fetchHistory({required int fromMillis});

  Future<List<AlertHistoryEntry>> fetchAlertHistory({int limit = 5});
}
