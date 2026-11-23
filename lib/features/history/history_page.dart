import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/time/wib_time.dart';
import '../thresholds/threshold_repository.dart';
import '../thresholds/thresholds.dart';
import 'alert_history_entry.dart';
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
  late Future<(List<HistoryReading>, Thresholds?, List<AlertHistoryEntry>)>
  _history;

  @override
  void initState() {
    super.initState();
    _history = _fetch();
  }

  Future<(List<HistoryReading>, Thresholds?, List<AlertHistoryEntry>)>
  _fetch() async {
    final fromMillis =
        DateTime.now().millisecondsSinceEpoch - _range.duration.inMilliseconds;
    final readings = widget.repository.fetchHistory(fromMillis: fromMillis);
    final thresholds = _loadThresholds();
    final alerts = _loadAlerts();
    return (await readings, await thresholds, await alerts);
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

  Future<List<AlertHistoryEntry>> _loadAlerts() async {
    try {
      return await widget.repository.fetchAlertHistory(limit: 5);
    } catch (_) {
      return const <AlertHistoryEntry>[];
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
            child:
                FutureBuilder<
                  (List<HistoryReading>, Thresholds?, List<AlertHistoryEntry>)
                >(
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

                    final readings =
                        snapshot.data?.$1 ?? const <HistoryReading>[];
                    final thresholds = snapshot.data?.$2;
                    final alerts =
                        snapshot.data?.$3 ?? const <AlertHistoryEntry>[];
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
                      alerts: alerts,
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
    return SegmentedButton<HistoryRange>(
      showSelectedIcon: false,
      segments: [
        for (final range in HistoryRange.values)
          ButtonSegment(value: range, label: Text(range.label)),
      ],
      selected: {selected},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }
        onSelected(selection.first);
      },
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.readings,
    required this.range,
    required this.thresholds,
    required this.alerts,
  });

  final List<HistoryReading> readings;
  final HistoryRange range;
  final Thresholds? thresholds;
  final List<AlertHistoryEntry> alerts;

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
        _AlertHistoryList(entries: alerts),
      ],
    );
  }
}

class _AlertHistoryList extends StatelessWidget {
  const _AlertHistoryList({required this.entries});

  final List<AlertHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text('5 peringatan terakhir', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Belum ada peringatan abnormal.',
              textAlign: .center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final entry in entries) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: .antiAlias,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.errorContainer,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                title: Text(
                  _alertTitle(entry.activeParameters),
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(formatWibTimestamp(entry.timestampMillis)),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatNumber(entry.temperature)} °C · '
                        '${_formatNumber(entry.humidity)}%',
                      ),
                    ],
                  ),
                ),
                isThreeLine: true,
              ),
            ),
          ],
      ],
    );
  }
}

String _alertTitle(List<String> parameters) {
  final hasTemperature = parameters.contains('temperature');
  final hasHumidity = parameters.contains('humidity');
  if (hasTemperature && hasHumidity) {
    return 'Suhu dan kelembapan di luar batas';
  }
  if (hasTemperature) {
    return 'Suhu di luar batas';
  }
  if (hasHumidity) {
    return 'Kelembapan di luar batas';
  }
  return 'Kondisi abnormal';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final values = [for (final reading in readings) valueOf(reading)];
    var lowest = values.first;
    var highest = values.first;
    for (final value in values) {
      if (value < lowest) {
        lowest = value;
      }
      if (value > highest) {
        highest = value;
      }
    }
    final suffix = unit == '%' ? '' : ' ';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: .antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$title ($unit)',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Column(
                  crossAxisAlignment: .end,
                  children: [
                    Text(
                      'Terakhir',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatNumber(values.last)}$suffix$unit',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ],
                ),
              ],
            ),
            if (bounds case (final min, final max)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Garis merah: batas normal '
                  '${_formatBound(min)}–${_formatBound(max)}'
                  '$suffix$unit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              height: 232,
              padding: const EdgeInsets.fromLTRB(2, 8, 12, 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _ReadingLineChart(
                readings: readings,
                color: color,
                unit: unit,
                range: range,
                valueOf: valueOf,
                bounds: bounds,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  'Terendah ${_formatNumber(lowest)}$suffix$unit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Tertinggi ${_formatNumber(highest)}$suffix$unit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
    required this.unit,
    required this.range,
    required this.valueOf,
    required this.bounds,
  });

  final List<HistoryReading> readings;
  final Color color;
  final String unit;
  final HistoryRange range;
  final double Function(HistoryReading) valueOf;
  final (double, double)? bounds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final axisStyle =
        theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ) ??
        const TextStyle(fontSize: 11);
    final suffix = unit == '%' ? '' : ' ';
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
      final padding = (maxY - minY) * 0.12;
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
            curveSmoothness: 0.32,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: readings.length <= 20,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchSpotThreshold: 24,
          touchTooltipData: LineTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(12),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.round();
                if (index < 0 || index >= readings.length) {
                  return null;
                }
                return LineTooltipItem(
                  '${_formatNumber(spot.y)}$suffix$unit\n${labelFor(index)}',
                  TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
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
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _formatNumber(value),
                    style: axisStyle,
                    textAlign: .end,
                    overflow: .ellipsis,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
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
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labelFor(index),
                    style: axisStyle,
                    maxLines: 1,
                    overflow: .ellipsis,
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
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outline.withValues(alpha: 0.12),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: limits == null
            ? null
            : ExtraLinesData(
                horizontalLines: [
                  for (final limit in [limits.$1, limits.$2])
                    HorizontalLine(
                      y: limit,
                      color: colorScheme.error,
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
