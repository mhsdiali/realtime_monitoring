import 'package:flutter/material.dart';

import '../../core/time/wib_time.dart';
import '../auth/auth_repository.dart';
import 'monitoring_repository.dart';
import 'monitoring_snapshot.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.authRepository,
    required this.monitoringRepository,
  });

  final AuthRepository authRepository;
  final MonitoringRepository monitoringRepository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Stream<MonitoringSnapshot> _snapshots;

  @override
  void initState() {
    super.initState();
    _snapshots = widget.monitoringRepository.watchDashboard();
  }

  Future<void> _signOut() async {
    try {
      await widget.authRepository.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal keluar. Silakan coba lagi.')),
        );
      }
    }
  }

  void _reload() {
    setState(() {
      _snapshots = widget.monitoringRepository.watchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<MonitoringSnapshot>(
        stream: _snapshots,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DashboardMessage(
              icon: Icons.cloud_off,
              title: 'Gagal memuat data.',
              subtitle: 'Periksa koneksi Anda lalu coba lagi.',
              action: FilledButton(
                onPressed: _reload,
                child: const Text('Coba lagi'),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final reading = data.reading;
          return Column(
            children: [
              _DeviceStatusBanner(
                isOnline: data.isOnline,
                hasReading: reading != null,
              ),
              Expanded(
                child: reading == null
                    ? const _DashboardMessage(
                        icon: Icons.sensors_off,
                        title: 'Belum ada data monitoring.',
                        subtitle:
                            'Data akan tampil otomatis saat perangkat '
                            'mengirim pembacaan.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _ReadingCard(
                            icon: Icons.thermostat,
                            label: 'Suhu',
                            value: '${_formatNumber(reading.temperature)} °C',
                          ),
                          const SizedBox(height: 12),
                          _ReadingCard(
                            icon: Icons.water_drop_outlined,
                            label: 'Kelembapan',
                            value: '${_formatNumber(reading.humidity)}%',
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: .start,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 20,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: .start,
                                  children: [
                                    Text(
                                      'Pembacaan terakhir',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatWibTimestamp(
                                        reading.timestampMillis,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}

class _DeviceStatusBanner extends StatelessWidget {
  const _DeviceStatusBanner({required this.isOnline, required this.hasReading});

  final bool isOnline;
  final bool hasReading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isOnline
        ? colorScheme.secondaryContainer
        : colorScheme.errorContainer;
    final foreground = isOnline
        ? colorScheme.onSecondaryContainer
        : colorScheme.onErrorContainer;
    final subtitle = isOnline
        ? 'Data diperbarui otomatis.'
        : hasReading
        ? 'Data yang tampil mungkin sudah usang.'
        : 'Belum ada data dari perangkat.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  isOnline ? 'Perangkat online' : 'Perangkat offline',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.displaySmall),
          ],
        ),
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: .center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: .center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
