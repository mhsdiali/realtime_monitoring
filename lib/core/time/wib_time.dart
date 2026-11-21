DateTime wibDateTime(int timestampMillis) {
  return DateTime.fromMillisecondsSinceEpoch(
    timestampMillis,
    isUtc: true,
  ).add(const Duration(hours: 7));
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String formatWibTimestamp(int timestampMillis) {
  final wib = wibDateTime(timestampMillis);
  return '${_twoDigits(wib.day)}/${_twoDigits(wib.month)}/${wib.year} '
      '${_twoDigits(wib.hour)}:${_twoDigits(wib.minute)}:'
      '${_twoDigits(wib.second)} WIB';
}

String formatWibClock(int timestampMillis) {
  final wib = wibDateTime(timestampMillis);
  return '${_twoDigits(wib.hour)}:${_twoDigits(wib.minute)}';
}

String formatWibClockSeconds(int timestampMillis) {
  final wib = wibDateTime(timestampMillis);
  return '${_twoDigits(wib.hour)}:${_twoDigits(wib.minute)}:'
      '${_twoDigits(wib.second)}';
}

String formatWibDate(int timestampMillis) {
  final wib = wibDateTime(timestampMillis);
  return '${_twoDigits(wib.day)}/${_twoDigits(wib.month)}';
}
