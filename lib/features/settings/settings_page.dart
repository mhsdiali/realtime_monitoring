import 'package:flutter/material.dart';

import '../thresholds/threshold_repository.dart';
import '../thresholds/thresholds_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.repository});

  final ThresholdRepository repository;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Preferensi',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: .antiAlias,
            child: ListTile(
              key: const Key('settings-threshold-tile'),
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.tune, color: colorScheme.onPrimaryContainer),
              ),
              title: const Text('Batas normal'),
              subtitle: const Text('Atur rentang suhu dan kelembapan gudang.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ThresholdsPage(repository: repository),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Pengaturan lain dapat ditambahkan di menu ini.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
