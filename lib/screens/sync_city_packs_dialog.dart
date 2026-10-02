import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/city_lab_operations.dart';

class SyncCityPacksDialog extends StatefulWidget {
  final AppState state;
  const SyncCityPacksDialog({super.key, required this.state});
  @override
  State<SyncCityPacksDialog> createState() => _SyncCityPacksDialogState();
}

class _SyncCityPacksDialogState extends State<SyncCityPacksDialog> {
  final operations = CityLabOperations();
  final source = TextEditingController();
  final python = TextEditingController(text: 'python');
  final project = TextEditingController();
  final selected = <String>{};
  List<Map<String, dynamic>> cities = [];
  Map<String, dynamic>? result;
  String? error;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await operations.load();
      source.text = operations.sourcePath;
      python.text = operations.pythonExecutable;
      project.text = operations.projectPath;
    } catch (e) {
      error = 'Settings could not be loaded: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    source.dispose();
    python.dispose();
    project.dispose();
    super.dispose();
  }

  Future<void> _run(bool sync) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      operations.sourcePath = source.text.trim();
      operations.pythonExecutable = python.text.trim();
      operations.projectPath = project.text.trim();
      await operations.save();
      if (sync) {
        // Close the active read only SQLite handle before replacing source files.
        await widget.state.repository?.database.db.close();
      }
      final response = await operations.run(sync ? 'sync' : 'discover', [
        '--source',
        operations.sourcePath,
        if (sync) ...['--cities', ...selected],
      ]);
      if (sync) {
        result = response;
      } else {
        cities = (response['cities'] as List).cast<Map<String, dynamic>>();
        selected.clear();
      }
    } catch (e) {
      error = e.toString();
    }
    if (sync) {
      try {
        final cityId = widget.state.activePack?.id;
        await widget.state.loadPacks();
        if (cityId != null) {
          final pack = widget.state.availablePacks
              .where((p) => p.id == cityId)
              .firstOrNull;
          if (pack != null) await widget.state.openPack(pack);
        }
      } catch (e) {
        error =
            '${error ?? "Sync completed"}. City reload failed: $e. Close and reopen the city.';
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sync Latest City Packs'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: source,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'DataFactory Repository',
              ),
            ),
            ExpansionTile(
              title: const Text('Local tools settings'),
              children: [
                TextField(
                  controller: project,
                  decoration: const InputDecoration(
                    labelText: 'City Lab checkout',
                  ),
                ),
                TextField(
                  controller: python,
                  decoration: const InputDecoration(
                    labelText: 'Python executable',
                  ),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              SelectableText(error!, style: const TextStyle(color: Colors.red)),
            for (final city in cities)
              CheckboxListTile(
                title: Text('${city['city_name']} ${city['version']}'),
                value: selected.contains(city['city_id']),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          selected.add(city['city_id'] as String);
                        } else {
                          selected.remove(city['city_id']);
                        }
                      }),
              ),
            if (result != null) ...[
              const Text(
                'Sync completed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final row in result!['results'] as List)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${row['city']} updated\nPlaces: ${row['places_before']} → ${row['places_after']}\n'
                    'Review candidates: ${row['candidates_before']} → ${row['candidates_after']}\n'
                    '${row['upstream_candidates_changed']} upstream candidates changed\n'
                    '${row['decisions_preserved']} curator decisions preserved\n'
                    '${row['reviewed_records_changed']} reviewed records need another review\n'
                    '${row['curation_files_lost']} curation files lost',
                  ),
                ),
              ExpansionTile(
                title: const Text('Technical logs'),
                children: [SelectableText(result!['logs'] as String? ?? '')],
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: busy ? null : () => _run(false),
        child: const Text('Verify source'),
      ),
      FilledButton(
        onPressed: busy || selected.isEmpty ? null : () => _run(true),
        child: const Text('Sync selected cities'),
      ),
    ],
  );
}
