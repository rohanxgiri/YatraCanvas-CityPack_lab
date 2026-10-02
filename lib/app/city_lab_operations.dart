import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Desktop orchestration only. Canonical certification stays in Python.
class CityLabOperations {
  String sourcePath = '';
  String pythonExecutable = 'python';
  String projectPath = kIsWeb ? '' : Directory.current.path;

  Future<File> _settings() async => File(
    p.join(
      (await getApplicationSupportDirectory()).path,
      'city_lab_operations.json',
    ),
  );

  Future<void> load() async {
    if (kIsWeb) return;
    final file = await _settings();
    if (!await file.exists()) return;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    sourcePath = data['source'] as String? ?? '';
    pythonExecutable = data['python'] as String? ?? 'python';
    projectPath = data['project'] as String? ?? Directory.current.path;
  }

  Future<void> save() async {
    if (kIsWeb) throw StateError('Local settings require the desktop app.');
    final file = await _settings();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'source': sourcePath,
        'python': pythonExecutable,
        'project': projectPath,
      }),
      flush: true,
    );
  }

  Future<Map<String, dynamic>> run(
    String operation,
    List<String> arguments,
  ) async {
    if (kIsWeb) {
      throw StateError('Sync and certified builds require the desktop app.');
    }
    final script = p.join(projectPath, 'tools', 'city_lab_operations.py');
    if (!await File(script).exists()) {
      throw StateError('Choose the City Lab checkout containing tools/.');
    }
    final process = await Process.run(
      pythonExecutable,
      [script, operation, ...arguments],
      workingDirectory: projectPath,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    Map<String, dynamic> result;
    try {
      result = jsonDecode(process.stdout as String) as Map<String, dynamic>;
    } catch (_) {
      throw StateError(
        'Operation could not start. Check the Python setting. ${process.stderr}',
      );
    }
    if (process.exitCode != 0 || result['ok'] != true) {
      throw StateError(result['error'] as String? ?? 'Operation failed');
    }
    return result;
  }
}
