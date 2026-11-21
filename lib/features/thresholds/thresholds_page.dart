import 'package:flutter/material.dart';

import 'threshold_repository.dart';
import 'thresholds.dart';

class ThresholdsPage extends StatefulWidget {
  const ThresholdsPage({super.key, required this.repository});

  final ThresholdRepository repository;

  @override
  State<ThresholdsPage> createState() => _ThresholdsPageState();
}

class _ThresholdsPageState extends State<ThresholdsPage> {
  final _formKey = GlobalKey<FormState>();
  final _temperatureMin = TextEditingController();
  final _temperatureMax = TextEditingController();
  final _humidityMin = TextEditingController();
  final _humidityMax = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _temperatureMin.dispose();
    _temperatureMax.dispose();
    _humidityMin.dispose();
    _humidityMax.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final thresholds =
          await widget.repository.loadThresholds() ?? Thresholds.defaults;
      if (!mounted) {
        return;
      }
      _temperatureMin.text = _formatValue(thresholds.temperatureMin);
      _temperatureMax.text = _formatValue(thresholds.temperatureMax);
      _humidityMin.text = _formatValue(thresholds.humidityMin);
      _humidityMax.text = _formatValue(thresholds.humidityMax);
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = 'Gagal memuat threshold.';
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final thresholds = Thresholds(
      temperatureMin: _parseValue(_temperatureMin.text)!,
      temperatureMax: _parseValue(_temperatureMax.text)!,
      humidityMin: _parseValue(_humidityMin.text)!,
      humidityMax: _parseValue(_humidityMax.text)!,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Simpan threshold?'),
          content: Text(
            'Suhu ${_formatValue(thresholds.temperatureMin)}–'
            '${_formatValue(thresholds.temperatureMax)} °C dan kelembapan '
            '${_formatValue(thresholds.humidityMin)}–'
            '${_formatValue(thresholds.humidityMax)}% akan disimpan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.saveThresholds(thresholds);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Threshold berhasil disimpan.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan threshold. Silakan coba lagi.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _LoadErrorMessage(onRetry: _load)
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Batas normal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atur batas normal suhu dan kelembapan gudang.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Suhu (°C)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: .start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('threshold-temperature-min'),
                          controller: _temperatureMin,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateTemperatureMin,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('threshold-temperature-max'),
                          controller: _temperatureMax,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateTemperatureMax,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Kelembapan (%)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: .start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('threshold-humidity-min'),
                          controller: _humidityMin,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateHumidityMin,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('threshold-humidity-max'),
                          controller: _humidityMax,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateHumidityMax,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Perubahan berlaku pada evaluasi notifikasi berikutnya.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan'),
                  ),
                ],
              ),
            ),
    );
  }

  String? _validateTemperatureMin(String? value) {
    final basic = _validateValue(
      value,
      min: 10,
      max: 40,
      rangeMessage: 'Suhu harus 10–40 °C.',
    );
    if (basic != null) {
      return basic;
    }
    final min = _parseValue(value)!;
    final max = _parseValue(_temperatureMax.text);
    if (max != null && min >= max) {
      return 'Min harus lebih kecil dari max.';
    }
    return null;
  }

  String? _validateTemperatureMax(String? value) {
    final basic = _validateValue(
      value,
      min: 10,
      max: 40,
      rangeMessage: 'Suhu harus 10–40 °C.',
    );
    if (basic != null) {
      return basic;
    }
    final max = _parseValue(value)!;
    final min = _parseValue(_temperatureMin.text);
    if (min != null && max <= min) {
      return 'Max harus lebih besar dari min.';
    }
    return null;
  }

  String? _validateHumidityMin(String? value) {
    final basic = _validateValue(
      value,
      min: 0,
      max: 100,
      rangeMessage: 'Kelembapan harus 0–100%.',
    );
    if (basic != null) {
      return basic;
    }
    final min = _parseValue(value)!;
    final max = _parseValue(_humidityMax.text);
    if (max != null && min >= max) {
      return 'Min harus lebih kecil dari max.';
    }
    return null;
  }

  String? _validateHumidityMax(String? value) {
    final basic = _validateValue(
      value,
      min: 0,
      max: 100,
      rangeMessage: 'Kelembapan harus 0–100%.',
    );
    if (basic != null) {
      return basic;
    }
    final max = _parseValue(value)!;
    final min = _parseValue(_humidityMin.text);
    if (min != null && max <= min) {
      return 'Max harus lebih besar dari min.';
    }
    return null;
  }

  String? _validateValue(
    String? value, {
    required double min,
    required double max,
    required String rangeMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Wajib diisi.';
    }
    final parsed = _parseValue(value);
    if (parsed == null) {
      return 'Harus berupa angka.';
    }
    if (parsed < min || parsed > max) {
      return rangeMessage;
    }
    return null;
  }

  double? _parseValue(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}

class _LoadErrorMessage extends StatelessWidget {
  const _LoadErrorMessage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat threshold.',
              textAlign: .center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Periksa koneksi Anda lalu coba lagi.',
              textAlign: .center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
