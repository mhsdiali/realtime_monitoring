import 'package:app_monitoring/core/time/wib_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('menampilkan epoch dalam WIB', () {
    expect(formatWibTimestamp(0), '01/01/1970 07:00:00 WIB');
  });

  test('menambahkan tujuh jam dari waktu UTC', () {
    final millis = DateTime.utc(2026, 11, 16, 10, 30, 5).millisecondsSinceEpoch;

    expect(formatWibTimestamp(millis), '16/11/2026 17:30:05 WIB');
  });

  test('memformat jam dan tanggal WIB untuk label grafik', () {
    final millis = DateTime.utc(2026, 11, 16, 10, 30, 5).millisecondsSinceEpoch;

    expect(formatWibClock(millis), '17:30');
    expect(formatWibClockSeconds(millis), '17:30:05');
    expect(formatWibDate(millis), '16/11');
  });
}
