import 'package:flutter/material.dart';

import '../../core/time/wib_time.dart';
import '../auth/auth_repository.dart';
import 'alert_state.dart';
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

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Keluar dari aplikasi?'),
          content: const Text(
            'Ponsel ini tidak akan menerima notifikasi sampai Anda masuk lagi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
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
            onPressed: _confirmSignOut,
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
          final alert = data.alert;
          final thresholds = data.thresholds;
          return Column(
            children: [
              if (!data.isConnected) const _ConnectionBanner(),
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
                          _ConditionCard(alert: alert, isOnline: data.isOnline),
                          const SizedBox(height: 12),
                          _ReadingCard(
                            icon: Icons.thermostat,
                            label: 'Suhu',
                            value: '${_formatNumber(reading.temperature)} °C',
                            range: thresholds == null
                                ? null
                                : '${_formatBound(thresholds.temperatureMin)}–'
                                      '${_formatBound(thresholds.temperatureMax)} °C',
                            abnormal: alert?.temperatureAbnormal ?? false,
                          ),
                          const SizedBox(height: 12),
                          _ReadingCard(
                            icon: Icons.water_drop_outlined,
                            label: 'Kelembapan',
                            value: '${_formatNumber(reading.humidity)}%',
                            range: thresholds == null
                                ? null
                                : '${_formatBound(thresholds.humidityMin)}–'
                                      '${_formatBound(thresholds.humidityMax)}%',
                            abnormal: alert?.humidityAbnormal ?? false,
                          ),
                          const SizedBox(height: 20),
                          _LastReading(
                            timestampMillis: reading.timestampMillis,
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
}

String _formatNumber(double value) {
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatBound(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return _formatNumber(value);
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.inverseSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 18, color: colorScheme.onInverseSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aplikasi tidak terhubung ke server. Data dapat tertinggal.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.onInverseSurface),
            ),
          ),
        ],
      ),
    );
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

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({required this.alert, required this.isOnline});

  final AlertState? alert;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final current = alert;

    final (IconData icon, String title, String detail, Color background, Color foreground) =
        switch (current) {
          null => (
            Icons.help_outline,
            'Kondisi belum dievaluasi',
            'Status normal atau abnormal dihitung oleh server notifikasi '
                'dan akan tampil setelah evaluasi pertama.',
            colorScheme.surfaceContainerHighest,
            colorScheme.onSurface,
          ),
          AlertState(isAbnormal: true) => (
            Icons.warning_amber_rounded,
            'Kondisi abnormal',
            _abnormalDetail(current),
            colorScheme.errorContainer,
            colorScheme.onErrorContainer,
          ),
          _ => (
            Icons.verified_outlined,
            'Kondisi normal',
            'Suhu dan kelembapan dalam batas normal.',
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer,
          ),
        };

    final notes = <String>[
      if (current?.updatedAtMillis case final updatedAt?)
        'Dievaluasi ${formatWibTimestamp(updatedAt)}',
      if (current != null && !isOnline) 'Berdasarkan pembacaan terakhir.',
    ];

    return Semantics(
      container: true,
      label: 'Kondisi gudang',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            Icon(icon, size: 32, color: foreground),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'Kondisi gudang',
                    style: textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: textTheme.bodyMedium?.copyWith(color: foreground),
                  ),
                  for (final note in notes) ...[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _abnormalDetail(AlertState alert) {
    if (alert.temperatureAbnormal && alert.humidityAbnormal) {
      return 'Suhu dan kelembapan di luar batas normal.';
    }
    if (alert.temperatureAbnormal) {
      return 'Suhu di luar batas normal.';
    }
    if (alert.humidityAbnormal) {
      return 'Kelembapan di luar batas normal.';
    }
    return 'Suhu dan/atau kelembapan di luar batas normal.';
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.range,
    required this.abnormal,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? range;
  final bool abnormal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = abnormal ? colorScheme.error : colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: abnormal
            ? BorderSide(color: colorScheme.error, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: textTheme.titleMedium)),
                if (abnormal)
                  Text(
                    'Di luar batas',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: textTheme.displaySmall?.copyWith(
                color: abnormal ? colorScheme.error : null,
              ),
            ),
            if (range != null) ...[
              const SizedBox(height: 6),
              Text(
                'Batas normal $range',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LastReading extends StatelessWidget {
  const _LastReading({required this.timestampMillis});

  final int timestampMillis;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(
                formatWibTimestamp(timestampMillis),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
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
