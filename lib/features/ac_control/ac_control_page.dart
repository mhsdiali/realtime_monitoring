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
  static const _minSetpoint = 16.0;
  static const _maxSetpoint = 30.0;

  late Stream<MonitoringSnapshot> _statusStream;
  StreamSubscription<dynamic>? _ackSubscription;
  Timer? _ackTimer;
  _CommandPhase _phase = _CommandPhase.idle;
  double _setpoint = 24;
  bool? _jetEnabled;
  bool? _swingEnabled;

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
    super.dispose();
  }

  void _changeSetpoint(double delta) {
    setState(() {
      _setpoint = (_setpoint + delta).clamp(_minSetpoint, _maxSetpoint);
    });
  }

  Future<bool> _send(
    AcAction action, {
    double? setpoint,
    bool? enabled,
    required bool isOnline,
  }) async {
    if (!isOnline || _busy) {
      return false;
    }

    _ackSubscription?.cancel();
    _ackTimer?.cancel();
    setState(() => _phase = _CommandPhase.sending);

    try {
      final commandId = await widget.repository.sendCommand(
        action: action,
        setpoint: setpoint,
        enabled: enabled,
      );
      if (!mounted) {
        return true;
      }
      setState(() => _phase = _CommandPhase.waiting);
      _listenForAcknowledgement(commandId);
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      setState(() => _phase = _CommandPhase.error);
      return false;
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
    await _send(
      AcAction.setTemperature,
      setpoint: _setpoint,
      isOnline: isOnline,
    );
  }

  Future<void> _setMode(
    AcAction action,
    bool enabled, {
    required bool isOnline,
  }) async {
    final previous = action == AcAction.setJet ? _jetEnabled : _swingEnabled;
    if (!isOnline || _busy || previous == enabled) {
      return;
    }

    setState(() {
      if (action == AcAction.setJet) {
        _jetEnabled = enabled;
      } else {
        _swingEnabled = enabled;
      }
    });

    final sent = await _send(action, enabled: enabled, isOnline: isOnline);
    if (!sent && mounted) {
      setState(() {
        if (action == AcAction.setJet) {
          _jetEnabled = previous;
        } else {
          _swingEnabled = previous;
        }
      });
    }
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              key: const Key('ac-setpoint-decrease'),
                              onPressed: enabled && _setpoint > _minSetpoint
                                  ? () => _changeSetpoint(-1)
                                  : null,
                              icon: const Icon(Icons.remove),
                              iconSize: 32,
                              tooltip: 'Turunkan suhu',
                            ),
                            const SizedBox(width: 24),
                            Text(
                              '${_setpoint.toInt()} °C',
                              key: const Key('ac-setpoint-value'),
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(width: 24),
                            IconButton.filledTonal(
                              key: const Key('ac-setpoint-increase'),
                              onPressed: enabled && _setpoint < _maxSetpoint
                                  ? () => _changeSetpoint(1)
                                  : null,
                              icon: const Icon(Icons.add),
                              iconSize: 32,
                              tooltip: 'Naikkan suhu',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rentang 16–30 °C',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
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
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        Text(
                          'Mode AC',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'JET',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          key: const Key('ac-jet-mode'),
                          emptySelectionAllowed: true,
                          selected: _jetEnabled == null
                              ? <bool>{}
                              : {_jetEnabled!},
                          onSelectionChanged: enabled
                              ? (selection) {
                                  if (selection.isEmpty) {
                                    return;
                                  }
                                  _setMode(
                                    AcAction.setJet,
                                    selection.first,
                                    isOnline: isOnline,
                                  );
                                }
                              : null,
                          segments: const [
                            ButtonSegment(value: false, label: Text('Non JET')),
                            ButtonSegment(value: true, label: Text('JET')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Swing',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          key: const Key('ac-swing-mode'),
                          emptySelectionAllowed: true,
                          selected: _swingEnabled == null
                              ? <bool>{}
                              : {_swingEnabled!},
                          onSelectionChanged: enabled
                              ? (selection) {
                                  if (selection.isEmpty) {
                                    return;
                                  }
                                  _setMode(
                                    AcAction.setSwing,
                                    selection.first,
                                    isOnline: isOnline,
                                  );
                                }
                              : null,
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Non Swing'),
                            ),
                            ButtonSegment(value: true, label: Text('Swing')),
                          ],
                        ),
                      ],
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
