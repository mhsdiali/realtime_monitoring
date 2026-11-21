const int offlineAfterMillis = 30000;

bool isDeviceOnline({required int? lastSeenMillis, required int nowMillis}) {
  if (lastSeenMillis == null) {
    return false;
  }
  return nowMillis - lastSeenMillis <= offlineAfterMillis;
}
