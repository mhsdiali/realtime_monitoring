import 'dart:async';

import 'package:flutter/material.dart';

import '../dashboard/monitoring_repository.dart';
import '../dashboard/monitoring_snapshot.dart';
import 'ac_action.dart';
import 'ac_control_repository.dart';

enum _CommandPhase { idle, sending, waiting, transmitted, timeout, error }

class AcControlPage extends StatefulWidget {
  const AcControlPage({
    super.key,
    required this.repository,
    required this.monitoringRepository,
  });

  final AcControlRepository repository;
  final MonitoringRepository monitoringRepository;

  @override
  State<AcControlPage> createState() => _AcControlPageState();
}

class _AcControlPageState extends State<AcControlPage> {
  final _setpointFormKey = GlobalKey<FormState>();
  final _setpointController = TextEditingController();

  late Stream<MonitoringSnapshot> _statusStream;
  StreamSubscription<dynamic>? _ackSubscription;
  Timer? _ackTimer;
  _CommandPhase _phase = _CommandPhase.idle;

  bool get _busy =>
      _phase == _CommandPhase.sending || _phase == _CommandPhase.waiting;

  @override
  void initState() {
    super.initState();
    _statusStream = widget.monitoringRepository.watchDashboard();
  }

  @override
  void dispose() {
    _ackSubscription?.cancel();
    _ackTimer?.cancel();
    _setpointController.dispose();
    super.dispose();
  }

  Future<void> _send(
    AcAction action, {
    double? setpoint,
    required bool isOnline,
  }) async {
    if (!isOnline || _busy) {
      return;
    }

    _ackSubscription?.cancel();
    _ackTimer?.cancel();
    setState(() => _phase = _CommandPhase.sending);

    try {
      final commandId = await widget.repository.sendCommand(
        action: action,
        setpoint: setpoint,
      );
      if (!mounted) {
        return;
      }
      setState(() => _phase = _CommandPhase.waiting);
      _listenForAcknowledgement(commandId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _phase = _CommandPhase.error);
    }
  }

  void _listenForAcknowledgement(String commandId) {
    _ackSubscription = widget.repository
        .watchAcknowledgement(commandId)
        .listen(
          (acknowledgement) {
            if (acknowledgement?.isTransmitted ?? false) {
              _ackTimer?.cancel();
              if (mounted) {
                setState(() => _phase = _CommandPhase.transmitted);
              }
            }
          },
          onError: (Object _) {
            if (mounted) {
              setState(() => _phase = _CommandPhase.error);
            }
          },
        );

    _ackTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      if (_phase == _CommandPhase.waiting) {
        setState(() => _phase = _CommandPhase.timeout);
      }
    });
  }

  Future<void> _confirmTurnOff(bool isOnline) async {
    if (!isOnline || _busy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Matikan AC?'),
          content: const Text(
            'Perintah mematikan AC akan dikirim ke perangkat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Matikan'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await _send(AcAction.turnOff, isOnline: isOnline);
    }
  }

  Future<void> _sendSetpoint(bool isOnline) async {
    if (!_setpointFormKey.currentState!.validate()) {
      return;
    }
    final value = double.parse(
      _setpointController.text.trim().replaceAll(',', '.'),
    );
    await _send(AcAction.setTemperature, setpoint: value, isOnline: isOnline);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontrol AC')),
      body: StreamBuilder<MonitoringSnapshot>(
        stream: _statusStream,
        builder: (context, snapshot) {
          final isOnline = snapshot.data?.isOnline ?? false;
          final enabled = isOnline && !_busy;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                _DeviceStatusBanner(isOnline: isOnline),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        Text(
                          'Daya AC',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: enabled
                              ? () => _send(AcAction.turnOn, isOnline: isOnline)
                              : null,
                          icon: const Icon(Icons.power_settings_new),
                          label: const Text('Nyalakan AC'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: enabled
                              ? () => _confirmTurnOff(isOnline)
                              : null,
                          icon: const Icon(Icons.power_off),
                          label: const Text('Matikan AC'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aplikasi hanya memancarkan sinyal IR, bukan '
                          'mengubah status AC secara langsung.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Form(
                    key: _setpointFormKey,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: .stretch,
                        children: [
                          Text(
                            'Atur Suhu',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('ac-setpoint'),
                            controller: _setpointController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Suhu AC (°C)',
                              hintText: '16–30',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Suhu wajib diisi.';
                              }
                              final parsed = double.tryParse(
                                value.trim().replaceAll(',', '.'),
                              );
                              if (parsed == null) {
                                return 'Harus berupa angka.';
                              }
                              if (parsed < 16 || parsed > 30) {
                                return 'Suhu harus 16–30 °C.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: enabled
                                ? () => _sendSetpoint(isOnline)
                                : null,
                            child: const Text('Kirim Suhu'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_phase != _CommandPhase.idle) ...[
                  const SizedBox(height: 16),
                  _CommandStatusCard(phase: _phase),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeviceStatusBanner extends StatelessWidget {
  const _DeviceStatusBanner({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isOnline
        ? colorScheme.secondaryContainer
        : colorScheme.errorContainer;
    final foreground = isOnline
        ? colorScheme.onSecondaryContainer
        : colorScheme.onErrorContainer;

    return Container(
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
                  isOnline
                      ? 'Kontrol AC dapat digunakan.'
                      : 'Kontrol AC dinonaktifkan.',
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

class _CommandStatusCard extends StatelessWidget {
  const _CommandStatusCard({required this.phase});

  final _CommandPhase phase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, title, subtitle, color) = switch (phase) {
      _CommandPhase.sending => (
        Icons.upload,
        'Mengirim perintah...',
        'Perintah sedang dikirim ke perangkat.',
        colorScheme.primary,
      ),
      _CommandPhase.waiting => (
        Icons.hourglass_top,
        'Menunggu konfirmasi perangkat...',
        'Konfirmasi maksimal 5 detik.',
        colorScheme.primary,
      ),
      _CommandPhase.transmitted => (
        Icons.check_circle_outline,
        'Sinyal IR telah dipancarkan.',
        'Status ini bukan konfirmasi bahwa AC berubah.',
        colorScheme.primary,
      ),
      _CommandPhase.timeout => (
        Icons.schedule,
        'Belum ada konfirmasi dalam 5 detik.',
        'Perintah tetap tersimpan dan akan dijalankan saat perangkat '
            'kembali online. Anda juga dapat mengulang perintah.',
        colorScheme.error,
      ),
      _CommandPhase.error => (
        Icons.error_outline,
        'Gagal mengirim perintah.',
        'Silakan coba lagi.',
        colorScheme.error,
      ),
      _CommandPhase.idle => (Icons.info_outline, '', '', colorScheme.primary),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
