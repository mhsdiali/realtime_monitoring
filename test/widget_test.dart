import 'dart:async';

import 'package:app_monitoring/app.dart';
import 'package:app_monitoring/features/auth/auth_failure.dart';
import 'package:app_monitoring/features/auth/auth_repository.dart';
import 'package:app_monitoring/features/ac_control/ac_acknowledgement.dart';
import 'package:app_monitoring/features/ac_control/ac_action.dart';
import 'package:app_monitoring/features/ac_control/ac_control_repository.dart';
import 'package:app_monitoring/features/dashboard/alert_state.dart';
import 'package:app_monitoring/features/dashboard/latest_reading.dart';
import 'package:app_monitoring/features/dashboard/monitoring_repository.dart';
import 'package:app_monitoring/features/dashboard/monitoring_snapshot.dart';
import 'package:app_monitoring/features/history/history_reading.dart';
import 'package:app_monitoring/features/history/history_repository.dart';
import 'package:app_monitoring/features/thresholds/threshold_repository.dart';
import 'package:app_monitoring/features/thresholds/thresholds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menampilkan halaman login saat belum masuk', (tester) async {
    final auth = FakeAuthRepository();
    final monitoring = FakeMonitoringRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monitoring Gudang'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Daftar'), findsNothing);
  });

  testWidgets('login berhasil membuka beranda', (tester) async {
    final auth = FakeAuthRepository();
    final monitoring = FakeMonitoringRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'petugas@contoh.id',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Beranda'), findsOneWidget);
    expect(find.text('Perangkat offline'), findsOneWidget);
    expect(find.text('Belum ada data monitoring.'), findsOneWidget);
    expect(auth.signIns.single, ('petugas@contoh.id', 'rahasia123'));
  });

  testWidgets('login gagal menampilkan pesan', (tester) async {
    final auth = FakeAuthRepository();
    auth.failure = const AuthFailure('Email atau kata sandi salah.');
    final monitoring = FakeMonitoringRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'petugas@contoh.id',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'salah');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Email atau kata sandi salah.'), findsOneWidget);
    expect(find.text('Beranda'), findsNothing);
  });

  testWidgets('menampilkan data dan status perangkat online', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(
        reading: LatestReading(
          temperature: 24.5,
          humidity: 55,
          timestampMillis: 0,
        ),
        isOnline: true,
      ),
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perangkat online'), findsOneWidget);
    expect(find.text('Data diperbarui otomatis.'), findsOneWidget);
    expect(find.text('24,5 °C'), findsOneWidget);
    expect(find.text('55,0%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('01/01/1970 07:00:00 WIB'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('01/01/1970 07:00:00 WIB'), findsOneWidget);
  });

  testWidgets('status offline tetap menampilkan data terakhir', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(
        reading: LatestReading(
          temperature: 24.5,
          humidity: 55,
          timestampMillis: 0,
        ),
        isOnline: false,
      ),
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perangkat offline'), findsOneWidget);
    expect(find.text('Data yang tampil mungkin sudah usang.'), findsOneWidget);
    expect(find.text('24,5 °C'), findsOneWidget);
    expect(find.text('55,0%'), findsOneWidget);
  });

  testWidgets('data berubah otomatis saat pembacaan baru masuk', (
    tester,
  ) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(
        reading: LatestReading(
          temperature: 24.5,
          humidity: 55,
          timestampMillis: 0,
        ),
        isOnline: true,
      ),
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    monitoring.emit(
      const MonitoringSnapshot(
        reading: LatestReading(
          temperature: 26.1,
          humidity: 61,
          timestampMillis: 60000,
        ),
        isOnline: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('26,1 °C'), findsOneWidget);
    expect(find.text('61,0%'), findsOneWidget);
    expect(find.text('24,5 °C'), findsNothing);
  });

  testWidgets('tab Riwayat menampilkan grafik dan daftar nilai', (
    tester,
  ) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository(
      readings: const [
        HistoryReading(temperature: 24.5, humidity: 55, timestampMillis: 0),
        HistoryReading(temperature: 25, humidity: 60, timestampMillis: 60000),
      ],
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(find.text('Suhu (°C)'), findsOneWidget);
    expect(find.text('Kelembapan (%)'), findsOneWidget);
    expect(find.text('6 jam'), findsOneWidget);
    expect(find.text('24 jam'), findsOneWidget);
    expect(find.text('7 hari'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('01/01/1970 07:00:00 WIB'), findsOneWidget);
    expect(find.text('01/01/1970 07:01:00 WIB'), findsOneWidget);
  });

  testWidgets('grafik riwayat menampilkan batas normal', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository(
      readings: const [
        HistoryReading(temperature: 18, humidity: 50, timestampMillis: 0),
        HistoryReading(temperature: 21, humidity: 62, timestampMillis: 60000),
      ],
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: FakeThresholdRepository(
          initial: Thresholds.defaults,
        ),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(
      find.text('Garis merah: batas normal 16–20 °C'),
      findsOneWidget,
    );
    expect(
      find.text('Garis merah: batas normal 40–60%'),
      findsOneWidget,
    );
  });

  testWidgets('riwayat tetap tampil bila batas normal gagal dimuat', (
    tester,
  ) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final thresholds = FakeThresholdRepository()..shouldFailLoad = true;
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(
          readings: const [
            HistoryReading(temperature: 18, humidity: 50, timestampMillis: 0),
          ],
        ),
        thresholdRepository: thresholds,
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(find.text('Suhu (°C)'), findsOneWidget);
    expect(find.textContaining('Garis merah'), findsNothing);
  });

  testWidgets('menampilkan keadaan kosong riwayat', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(
      find.text('Belum ada data riwayat pada rentang ini.'),
      findsOneWidget,
    );
  });

  testWidgets('mengganti rentang memuat ulang riwayat', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository(
      readings: const [
        HistoryReading(temperature: 24.5, humidity: 55, timestampMillis: 0),
      ],
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(history.calls, hasLength(1));

    await tester.tap(find.text('6 jam'));
    await tester.pumpAndSettle();
    expect(history.calls, hasLength(2));
  });

  testWidgets('menampilkan galat saat riwayat gagal dimuat', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository()..shouldFail = true;
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat riwayat.'), findsOneWidget);
  });

  testWidgets('tab Pengaturan menampilkan threshold awal', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository();
    final thresholds = FakeThresholdRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: thresholds,
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Pengaturan'), findsOneWidget);
    expect(find.text('Batas normal'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('menyimpan threshold setelah konfirmasi', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository();
    final thresholds = FakeThresholdRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: thresholds,
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('threshold-temperature-min')),
      '17',
    );
    await tester.enterText(
      find.byKey(const Key('threshold-temperature-max')),
      '19',
    );
    await tester.enterText(
      find.byKey(const Key('threshold-humidity-min')),
      '45',
    );
    await tester.enterText(
      find.byKey(const Key('threshold-humidity-max')),
      '55',
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan threshold?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Simpan'),
      ),
    );
    await tester.pumpAndSettle();

    expect(thresholds.saved?.temperatureMin, 17);
    expect(thresholds.saved?.temperatureMax, 19);
    expect(thresholds.saved?.humidityMin, 45);
    expect(thresholds.saved?.humidityMax, 55);
    expect(find.text('Threshold berhasil disimpan.'), findsOneWidget);
  });

  testWidgets('menolak threshold dengan min lebih besar dari max', (
    tester,
  ) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository();
    final thresholds = FakeThresholdRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: thresholds,
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('threshold-temperature-min')),
      '25',
    );
    await tester.enterText(
      find.byKey(const Key('threshold-temperature-max')),
      '20',
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Min harus lebih kecil dari max.'), findsOneWidget);
    expect(find.text('Simpan threshold?'), findsNothing);
    expect(thresholds.saved, isNull);
  });

  testWidgets('menampilkan galat saat threshold gagal dimuat', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final history = FakeHistoryRepository();
    final thresholds = FakeThresholdRepository()..shouldFailLoad = true;
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: history,
        thresholdRepository: thresholds,
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat threshold.'), findsOneWidget);
  });

  testWidgets('kontrol AC dinonaktifkan saat perangkat offline', (
    tester,
  ) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(isOnline: false),
    );
    final ac = FakeAcControlRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);
    addTearDown(ac.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: ac,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kontrol AC'));
    await tester.pumpAndSettle();

    expect(find.text('Perangkat offline'), findsOneWidget);
    expect(find.text('Kontrol AC dinonaktifkan.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nyalakan AC'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('menyalakan AC menampilkan sinyal dipancarkan', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(isOnline: true),
    );
    final ac = FakeAcControlRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);
    addTearDown(ac.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: ac,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kontrol AC'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nyalakan AC'));
    await tester.pumpAndSettle();

    expect(ac.sent.single, (AcAction.turnOn, null));
    expect(find.text('Menunggu konfirmasi perangkat...'), findsOneWidget);

    ac.emitAcknowledgement(const AcAcknowledgement(status: 'transmitted'));
    await tester.pumpAndSettle();

    expect(find.text('Sinyal IR telah dipancarkan.'), findsOneWidget);
    expect(
      find.text('Status ini bukan konfirmasi bahwa AC berubah.'),
      findsOneWidget,
    );
  });

  testWidgets('mematikan AC meminta konfirmasi', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(isOnline: true),
    );
    final ac = FakeAcControlRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);
    addTearDown(ac.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: ac,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kontrol AC'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Matikan AC'));
    await tester.pumpAndSettle();
    expect(find.text('Matikan AC?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(ac.sent, isEmpty);

    await tester.tap(find.text('Matikan AC'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Matikan'));
    await tester.pumpAndSettle();

    expect(ac.sent.single, (AcAction.turnOff, null));
  });

  testWidgets('memvalidasi setpoint AC 16-30 derajat', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(isOnline: true),
    );
    final ac = FakeAcControlRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);
    addTearDown(ac.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: ac,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kontrol AC'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ac-setpoint')), '31');
    await tester.ensureVisible(find.text('Kirim Suhu'));
    await tester.tap(find.text('Kirim Suhu'));
    await tester.pumpAndSettle();

    expect(find.text('Suhu harus 16–30 °C.'), findsOneWidget);
    expect(ac.sent, isEmpty);

    await tester.enterText(find.byKey(const Key('ac-setpoint')), '24');
    await tester.tap(find.text('Kirim Suhu'));
    await tester.pumpAndSettle();

    expect(ac.sent.single, (AcAction.setTemperature, 24.0));
  });

  testWidgets('menampilkan timeout setelah 5 detik tanpa ack', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(isOnline: true),
    );
    final ac = FakeAcControlRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);
    addTearDown(ac.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: ac,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kontrol AC'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nyalakan AC'));
    await tester.pumpAndSettle();
    expect(find.text('Menunggu konfirmasi perangkat...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Belum ada konfirmasi dalam 5 detik.'), findsOneWidget);
  });

  testWidgets('tab controller mengembalikan tampilan ke Beranda', (
    tester,
  ) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    final tabController = ValueNotifier<int>(0);
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);
    addTearDown(tabController.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
        tabController: tabController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Riwayat'), findsOneWidget);

    tabController.value = 0;
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Beranda'), findsOneWidget);
  });

  testWidgets('logout kembali ke halaman login', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Beranda'), findsOneWidget);

    await tester.tap(find.byTooltip('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari aplikasi?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('batal keluar tetap di beranda', (tester) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository();
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Beranda'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsNothing);
  });

  testWidgets('menampilkan kondisi abnormal dan parameter yang bermasalah', (
    tester,
  ) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(
        reading: LatestReading(
          temperature: 23.4,
          humidity: 55,
          timestampMillis: 0,
        ),
        isOnline: true,
        alert: AlertState(
          status: AlertStatus.abnormal,
          activeParameters: ['temperature'],
          updatedAtMillis: 0,
        ),
        thresholds: Thresholds.defaults,
      ),
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kondisi abnormal'), findsOneWidget);
    expect(find.text('Suhu di luar batas normal.'), findsOneWidget);
    expect(find.text('Di luar batas'), findsOneWidget);
    expect(find.text('Batas normal 16–20 °C'), findsOneWidget);
    expect(find.text('Batas normal 40–60%'), findsOneWidget);
    expect(find.text('Dievaluasi 01/01/1970 07:00:00 WIB'), findsOneWidget);
  });

  testWidgets('kondisi normal dan belum dievaluasi', (tester) async {
    final auth = FakeAuthRepository(true);
    const reading = LatestReading(
      temperature: 18,
      humidity: 50,
      timestampMillis: 0,
    );
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(reading: reading, isOnline: true),
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kondisi belum dievaluasi'), findsOneWidget);

    monitoring.emit(
      const MonitoringSnapshot(
        reading: reading,
        isOnline: true,
        alert: AlertState(status: AlertStatus.normal),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kondisi normal'), findsOneWidget);
    expect(find.text('Di luar batas'), findsNothing);
  });

  testWidgets('menampilkan banner saat aplikasi terputus dari server', (
    tester,
  ) async {
    final auth = FakeAuthRepository(true);
    final monitoring = FakeMonitoringRepository(
      const MonitoringSnapshot(isOnline: false, isConnected: false),
    );
    addTearDown(auth.dispose);
    addTearDown(monitoring.dispose);

    await tester.pumpWidget(
      AppMonitoringApp(
        authRepository: auth,
        monitoringRepository: monitoring,
        historyRepository: FakeHistoryRepository(),
        thresholdRepository: FakeThresholdRepository(),
        acControlRepository: FakeAcControlRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Aplikasi tidak terhubung ke server. Data dapat tertinggal.'),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan galat bila Firebase gagal dimulai', (tester) async {
    await tester.pumpWidget(
      const AppMonitoringApp(
        authRepository: null,
        monitoringRepository: null,
        historyRepository: null,
        thresholdRepository: null,
        acControlRepository: null,
        firebaseError: 'error',
      ),
    );

    expect(find.text('Firebase belum terhubung'), findsOneWidget);
    expect(find.text('Konfigurasi Firebase belum tersedia.'), findsOneWidget);
  });
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([this._signedIn = false]);

  final _changes = StreamController<bool>.broadcast();
  final List<(String, String)> signIns = [];
  bool _signedIn;
  AuthFailure? failure;

  @override
  Stream<bool> get signedInChanges async* {
    yield _signedIn;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signIns.add((email, password));
    if (failure != null) {
      throw failure!;
    }
    _signedIn = true;
    _changes.add(true);
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _changes.add(false);
  }

  void dispose() {
    _changes.close();
  }
}

class FakeMonitoringRepository implements MonitoringRepository {
  FakeMonitoringRepository([
    this._initial = const MonitoringSnapshot(isOnline: false),
  ]);

  final MonitoringSnapshot _initial;
  final _changes = StreamController<MonitoringSnapshot>.broadcast();

  @override
  Stream<MonitoringSnapshot> watchDashboard() async* {
    yield _initial;
    yield* _changes.stream;
  }

  void emit(MonitoringSnapshot snapshot) {
    _changes.add(snapshot);
  }

  void dispose() {
    _changes.close();
  }
}

class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository({this.readings = const []});

  final List<HistoryReading> readings;
  final List<int> calls = [];
  bool shouldFail = false;

  @override
  Future<List<HistoryReading>> fetchHistory({required int fromMillis}) async {
    calls.add(fromMillis);
    if (shouldFail) {
      throw Exception('riwayat gagal');
    }
    return readings;
  }
}

class FakeThresholdRepository implements ThresholdRepository {
  FakeThresholdRepository({this.initial});

  Thresholds? initial;
  Thresholds? saved;
  bool shouldFailLoad = false;
  bool shouldFailSave = false;

  @override
  Future<Thresholds?> loadThresholds() async {
    if (shouldFailLoad) {
      throw Exception('threshold gagal dimuat');
    }
    return initial;
  }

  @override
  Future<void> saveThresholds(Thresholds thresholds) async {
    if (shouldFailSave) {
      throw Exception('threshold gagal disimpan');
    }
    saved = thresholds;
  }
}

class FakeAcControlRepository implements AcControlRepository {
  final List<(AcAction, double?)> sent = [];
  final _acknowledgements = StreamController<AcAcknowledgement?>.broadcast();

  @override
  Future<String> sendCommand({
    required AcAction action,
    double? setpoint,
  }) async {
    sent.add((action, setpoint));
    return 'cmd-${sent.length}';
  }

  @override
  Stream<AcAcknowledgement?> watchAcknowledgement(String commandId) {
    return _acknowledgements.stream;
  }

  void emitAcknowledgement(AcAcknowledgement acknowledgement) {
    _acknowledgements.add(acknowledgement);
  }

  void dispose() {
    _acknowledgements.close();
  }
}
