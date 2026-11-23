import 'package:flutter/material.dart';

import '../ac_control/ac_control_page.dart';
import '../ac_control/ac_control_repository.dart';
import '../auth/auth_repository.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/monitoring_repository.dart';
import '../history/history_page.dart';
import '../history/history_repository.dart';
import '../settings/settings_page.dart';
import '../thresholds/threshold_repository.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.authRepository,
    required this.monitoringRepository,
    required this.historyRepository,
    required this.thresholdRepository,
    required this.acControlRepository,
    this.tabController,
  });

  final AuthRepository authRepository;
  final MonitoringRepository monitoringRepository;
  final HistoryRepository historyRepository;
  final ThresholdRepository thresholdRepository;
  final AcControlRepository acControlRepository;
  final ValueNotifier<int>? tabController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final ValueNotifier<int> _tabController;
  late final bool _ownsTabController;

  int get _selectedIndex => _tabController.value;

  @override
  void initState() {
    super.initState();
    _ownsTabController = widget.tabController == null;
    _tabController = widget.tabController ?? ValueNotifier(0);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    if (_ownsTabController) {
      _tabController.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardPage(
            authRepository: widget.authRepository,
            monitoringRepository: widget.monitoringRepository,
          ),
          HistoryPage(
            repository: widget.historyRepository,
            thresholdRepository: widget.thresholdRepository,
          ),
          AcControlPage(
            repository: widget.acControlRepository,
            monitoringRepository: widget.monitoringRepository,
          ),
          SettingsPage(repository: widget.thresholdRepository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          _tabController.value = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.ac_unit_outlined),
            selectedIcon: Icon(Icons.ac_unit),
            label: 'Kontrol AC',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
