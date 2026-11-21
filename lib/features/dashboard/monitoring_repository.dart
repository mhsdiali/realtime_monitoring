import 'monitoring_snapshot.dart';

abstract interface class MonitoringRepository {
  Stream<MonitoringSnapshot> watchDashboard();
}
