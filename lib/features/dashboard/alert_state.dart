enum AlertStatus { normal, abnormal }

/// Hasil evaluasi kondisi gudang dari node `alert_state`.
///
/// Node ini hanya ditulis notification worker di VPS. Aplikasi membacanya saja
/// dan tidak menghitung status sendiri, supaya status di layar sama dengan
/// status yang memicu notifikasi.
class AlertState {
  const AlertState({
    required this.status,
    this.activeParameters = const [],
    this.updatedAtMillis,
  });

  final AlertStatus status;

  /// Berisi `temperature` dan/atau `humidity`. RTDB tidak menyimpan array
  /// kosong, jadi node yang hilang berarti daftar kosong.
  final List<String> activeParameters;
  final int? updatedAtMillis;

  bool get isAbnormal => status == AlertStatus.abnormal;
  bool get temperatureAbnormal => activeParameters.contains('temperature');
  bool get humidityAbnormal => activeParameters.contains('humidity');

  static AlertState? fromValue(Object? value) {
    if (value is! Map) {
      return null;
    }
    final status = switch (value['status']) {
      'normal' => AlertStatus.normal,
      'abnormal' => AlertStatus.abnormal,
      _ => null,
    };
    if (status == null) {
      return null;
    }

    final rawParameters = value['active_parameters'];
    final Iterable<Object?> items = switch (rawParameters) {
      List() => rawParameters,
      Map() => rawParameters.values,
      _ => const [],
    };

    return AlertState(
      status: status,
      activeParameters: [
        for (final item in items)
          if (item is String) item,
      ],
      updatedAtMillis: (value['updated_at'] as num?)?.toInt(),
    );
  }
}
