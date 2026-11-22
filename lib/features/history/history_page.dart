import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/time/wib_time.dart';
import '../thresholds/threshold_repository.dart';
import '../thresholds/thresholds.dart';
import 'history_reading.dart';
import 'history_repository.dart';

enum HistoryRange {
  sixHours('6 jam', Duration(hours: 6)),
  twentyFourHours('24 jam', Duration(hours: 24)),
  sevenDays('7 hari', Duration(days: 7));

  const HistoryRange(this.label, this.duration);

  final String label;
  final Duration duration;
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.repository,
    this.thresholdRepository,
  });

  final HistoryRepository repository;

  /// Opsional: bila tersedia, batas normal digambar sebagai garis di grafik.
  final ThresholdRepository? thresholdRepository;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryRange _range = HistoryRange.twentyFourHours;
  late Future<(List<HistoryReading>, Thresholds?)> _history;

  @override
  void initState() {
    super.initState();
    _history = _fetch();
  }

  Future<(List<HistoryReading>, Thresholds?)> _fetch() async {
    final fromMillis =
        DateTime.now().millisecondsSinceEpoch - _range.duration.inMilliseconds;
    final readings = widget.repository.fetchHistory(fromMillis: fromMillis);
    final thresholds = _loadThresholds();
    return (await readings, await thresholds);
  }

  /// Batas normal hanya pelengkap grafik; kegagalannya tidak boleh
  /// menggagalkan tampilan riwayat.
  Future<Thresholds?> _loadThresholds() async {
    try {
      return await widget.thresholdRepository?.loadThresholds();
    } catch (_) {
      return null;
    }
  }

  void _reload() {
    setState(() {
      _history = _fetch();
    });
  }

  void _selectRange(HistoryRange range) {
    if (range == _range) {
      return;
    }
    setState(() {
      _range = range;
      _history = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _RangeSelector(selected: _range, onSelected: _selectRange),
          ),
          Expanded(
            child: FutureBuilder<(List<HistoryReading>, Thresholds?)>(
              future: _history,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _HistoryMessage(
                    icon: Icons.cloud_off,
                    title: 'Gagal memuat riwayat.',
                    subtitle: 'Periksa koneksi Anda lalu coba lagi.',
                    action: FilledButton(
                      onPressed: _reload,
                      child: const Text('Coba lagi'),
                    ),
                  );
                }

                final readings = snapshot.data?.$1 ?? const <HistoryReading>[];
                final thresholds = snapshot.data?.$2;
                if (readings.isEmpty) {
                  return const _HistoryMessage(
                    icon: Icons.history_toggle_off,
                    title: 'Belum ada data riwayat pada rentang ini.',
                    subtitle:
                        'Riwayat akan tampil setelah perangkat mengirim data.',
                  );
                }

                return _HistoryContent(
                  readings: readings,
                  range: _range,
                  thresholds: thresholds,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});

  final HistoryRange selected;
  final ValueChanged<HistoryRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final range in HistoryRange.values)
          ChoiceChip(
            label: Text(range.label),
            selected: selected == range,
            onSelected: (_) => onSelected(range),
          ),
      ],
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.readings,
    required this.range,
    required this.thresholds,
  });

  final List<HistoryReading> readings;
  final HistoryRange range;
  final Thresholds? thresholds;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _ReadingChartCard(
          icon: Icons.thermostat,
          title: 'Suhu',
          unit: '°C',
          color: colorScheme.primary,
          readings: readings,
          range: range,
          valueOf: (reading) => reading.temperature,
          bounds: thresholds == null
              ? null
              : (thresholds!.temperatureMin, thresholds!.temperatureMax),
        ),
        const SizedBox(height: 12),
        _ReadingChartCard(
          icon: Icons.water_drop_outlined,
          title: 'Kelembapan',
          unit: '%',
          color: colorScheme.tertiary,
          readings: readings,
          range: range,
          valueOf: (reading) => reading.humidity,
          bounds: thresholds == null
              ? null
              : (thresholds!.humidityMin, thresholds!.humidityMax),
        ),
        const SizedBox(height: 24),
        Text('Daftar nilai', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final reading in readings.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.schedule,
              color: Theme.of(context).colorScheme.outline,
            ),
            title: Text(formatWibTimestamp(reading.timestampMillis)),
            subtitle: Text(
              '${_formatNumber(reading.temperature)} °C · '
              '${_formatNumber(reading.humidity)}%',
            ),
          ),
      ],
    );
  }
}

class _ReadingChartCard extends StatelessWidget {
  const _ReadingChartCard({
    required this.icon,
    required this.title,
    required this.unit,
    required this.color,
    required this.readings,
    required this.range,
    required this.valueOf,
    required this.bounds,
  });

  final IconData icon;
  final String title;
  final String unit;
  final Color color;
  final List<HistoryReading> readings;
  final HistoryRange range;
  final double Function(HistoryReading) valueOf;
  final (double, double)? bounds;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  '$title ($unit)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (bounds case (final min, final max)) ...[
              const SizedBox(height: 4),
              Text(
                'Garis merah: batas normal '
                '${_formatBound(min)}–${_formatBound(max)}'
                '${unit == '%' ? '' : ' '}$unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: _ReadingLineChart(
                readings: readings,
                color: color,
                range: range,
                valueOf: valueOf,
                bounds: bounds,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingLineChart extends StatelessWidget {
  const _ReadingLineChart({
    required this.readings,
    required this.color,
    required this.range,
    required this.valueOf,
    required this.bounds,
  });

  final List<HistoryReading> readings;
  final Color color;
  final HistoryRange range;
  final double Function(HistoryReading) valueOf;
  final (double, double)? bounds;

  @override
  Widget build(BuildContext context) {
    final values = [for (final reading in readings) valueOf(reading)];
    final limits = bounds;
    var minY = values.first;
    var maxY = values.first;
    for (final value in [...values, ?limits?.$1, ?limits?.$2]) {
      if (value < minY) {
        minY = value;
      }
      if (value > maxY) {
        maxY = value;
      }
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    } else {
      final padding = (maxY - minY) * 0.15;
      minY -= padding;
      maxY += padding;
    }

    final spots = [
      for (var index = 0; index < values.length; index++)
        FlSpot(index.toDouble(), values[index]),
    ];
    final maxX = readings.length == 1 ? 1.0 : (readings.length - 1).toDouble();
    final interval = readings.length <= 4 ? 1.0 : (maxX / 3).ceilToDouble();
    final yInterval = (maxY - minY) / 4;

    final firstWib = wibDateTime(readings.first.timestampMillis);
    final lastWib = wibDateTime(readings.last.timestampMillis);
    final sameDay =
        firstWib.year == lastWib.year &&
        firstWib.month == lastWib.month &&
        firstWib.day == lastWib.day;

    String labelFor(int index) {
      final timestamp = readings[index].timestampMillis;
      if (range == HistoryRange.sevenDays && !sameDay) {
        return formatWibDate(timestamp);
      }
      return formatWibClockSeconds(timestamp);
    }

    final labelIndices = <int>{};
    final labelsSeen = <String>{};
    final step = interval.round();
    for (var index = 0; index < readings.length; index += step) {
      if (labelsSeen.add(labelFor(index))) {
        labelIndices.add(index);
      }
    }
    final lastIndex = readings.length - 1;
    if (labelsSeen.add(labelFor(lastIndex))) {
      labelIndices.add(lastIndex);
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: readings.length > 2,
            curveSmoothness: 0.2,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: readings.length <= 20),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatNumber(value),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 ||
                    index >= readings.length ||
                    !labelIndices.contains(index) ||
                    (value - index).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labelFor(index),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: limits == null
            ? null
            : ExtraLinesData(
                horizontalLines: [
                  for (final limit in [limits.$1, limits.$2])
                    HorizontalLine(
                      y: limit,
                      color: Theme.of(context).colorScheme.error,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                    ),
                ],
              ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
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

String _formatNumber(double value) {
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatBound(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return _formatNumber(value);
}
