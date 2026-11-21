import 'package:flutter/material.dart';

import 'features/ac_control/ac_control_repository.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/auth_repository.dart';
import 'features/dashboard/monitoring_repository.dart';
import 'features/history/history_repository.dart';
import 'features/thresholds/threshold_repository.dart';

class AppMonitoringApp extends StatelessWidget {
  const AppMonitoringApp({
    super.key,
    required this.authRepository,
    required this.monitoringRepository,
    required this.historyRepository,
    required this.thresholdRepository,
    required this.acControlRepository,
    this.tabController,
    this.firebaseError,
  });

  final AuthRepository? authRepository;
  final MonitoringRepository? monitoringRepository;
  final HistoryRepository? historyRepository;
  final ThresholdRepository? thresholdRepository;
  final AcControlRepository? acControlRepository;
  final ValueNotifier<int>? tabController;
  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoring Gudang SPPG',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.green)),
      home: firebaseError == null
          ? AuthGate(
              repository: authRepository!,
              monitoringRepository: monitoringRepository!,
              historyRepository: historyRepository!,
              thresholdRepository: thresholdRepository!,
              acControlRepository: acControlRepository!,
              tabController: tabController,
            )
          : const FirebaseErrorPage(),
    );
  }
}

class FirebaseErrorPage extends StatelessWidget {
  const FirebaseErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Gudang'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'SPPG Lenteng Timur 2',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Firebase belum terhubung',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Konfigurasi Firebase belum tersedia.',
                textAlign: .center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
