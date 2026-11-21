import 'history_reading.dart';

abstract interface class HistoryRepository {
  Future<List<HistoryReading>> fetchHistory({required int fromMillis});
}
