import 'package:flutter/material.dart';

import '../dashboard/monitoring_repository.dart';
import '../history/history_repository.dart';
import '../home/home_shell.dart';
import '../ac_control/ac_control_repository.dart';
import '../thresholds/threshold_repository.dart';
import 'auth_repository.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.repository,
    required this.monitoringRepository,
    required this.historyRepository,
    required this.thresholdRepository,
    required this.acControlRepository,
    this.tabController,
  });

  final AuthRepository repository;
  final MonitoringRepository monitoringRepository;
  final HistoryRepository historyRepository;
  final ThresholdRepository thresholdRepository;
  final AcControlRepository acControlRepository;
  final ValueNotifier<int>? tabController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: repository.signedInChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data ?? false) {
          return HomeShell(
            authRepository: repository,
            monitoringRepository: monitoringRepository,
            historyRepository: historyRepository,
            thresholdRepository: thresholdRepository,
            acControlRepository: acControlRepository,
            tabController: tabController,
          );
        }
        return LoginPage(repository: repository);
      },
    );
  }
}
