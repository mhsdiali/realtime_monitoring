import 'package:app_monitoring/features/dashboard/device_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('online saat selisih tepat 30 detik', () {
    expect(isDeviceOnline(lastSeenMillis: 0, nowMillis: 30000), isTrue);
  });

  test('offline setelah lebih dari 30 detik', () {
    expect(isDeviceOnline(lastSeenMillis: 0, nowMillis: 30001), isFalse);
  });

  test('offline bila last_seen belum pernah ada', () {
    expect(isDeviceOnline(lastSeenMillis: null, nowMillis: 30000), isFalse);
  });

  test('toleransi jam perangkat yang lebih cepat', () {
    expect(isDeviceOnline(lastSeenMillis: 5000, nowMillis: 0), isTrue);
  });
}
