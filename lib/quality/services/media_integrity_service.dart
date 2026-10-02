import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class MediaIntegrityService {
  final String workspaceRoot;
  const MediaIntegrityService({this.workspaceRoot = '.'});
  Future<List<String>> validate(
    String cityId, {
    Set<String> excluded = const {},
    Map<String, String> overrides = const {},
  }) async {
    final blockers = <String>[];
    final base = p
        .normalize(p.join(workspaceRoot, 'assets', 'city_packs', cityId))
        .replaceAll('\\', '/');
    for (final name in ['image_manifest.json', 'images_manifest.json']) {
      String raw;
      try {
        raw = kIsWeb
            ? await rootBundle.loadString('$base/$name')
            : await File(p.join(base, name)).readAsString();
      } catch (_) {
        continue;
      }
      try {
        final entries = jsonDecode(raw) as Map<String, dynamic>;
        int missing = 0;
        int metadata = 0;
        for (final entry in entries.entries) {
          if (excluded.contains(entry.key) ||
              overrides.containsKey(entry.key)) {
            continue;
          }
          final data = entry.value as Map<String, dynamic>;
          final items = [
            if (data['primary'] != null) data['primary'],
            ...?data['gallery'] as List<dynamic>?,
          ];
          for (final value in items) {
            final item = value as Map<String, dynamic>;
            for (final key in ['local_path', 'thumbnail_path']) {
              final path = item[key] as String?;
              if (path == null || path.isEmpty) {
                if (key == 'local_path') missing++;
                continue;
              }
              if (p.isAbsolute(path) ||
                  p.split(p.normalize(path)).contains('..')) {
                missing++;
                continue;
              }
              if (kIsWeb) {
                try {
                  await rootBundle.load('$base/$path');
                } catch (_) {
                  missing++;
                }
              } else if (!await File(p.join(base, path)).exists()) {
                missing++;
              }
            }
            final license = (item['license'] as String? ?? '')
                .trim()
                .toLowerCase();
            if (const ['', 'unknown', 'unverified'].contains(license) ||
                ((item['author'] as String? ?? '').trim().isEmpty &&
                    (item['attribution'] as String? ?? '').trim().isEmpty)) {
              metadata++;
            }
          }
        }
        if (missing > 0) {
          blockers.add(
            '$name has $missing broken published media references. Sync to remove unavailable optional gallery items.',
          );
        }
        if (metadata > 0) {
          blockers.add(
            '$name has $metadata media records missing license or author/attribution evidence.',
          );
        }
      } catch (e) {
        blockers.add('$name cannot be validated: $e');
      }
    }
    if (kIsWeb && overrides.values.any((path) => path.isNotEmpty)) {
      blockers.add(
        'Image overrides require local file and attribution validation in the desktop app before certification.',
      );
    }
    if (!kIsWeb) {
      for (final entry in overrides.entries) {
        if (excluded.contains(entry.key) || entry.value.isEmpty) continue;
        final path = entry.value;
        if (p.isAbsolute(path) ||
            p.split(p.normalize(path)).contains('..') ||
            !await File(p.join(base, path)).exists()) {
          blockers.add(
            '${entry.key}: replacement primary image is missing or unsafe.',
          );
          continue;
        }
        try {
          final metadata = jsonDecode(
            await File(p.join(base, 'curation', 'media', '${entry.key}.json'))
                .readAsString(),
          ) as Map<String, dynamic>;
          if (metadata['primaryImagePath'] != path ||
              (metadata['author'] as String? ?? '').trim().isEmpty ||
              const ['', 'unknown', 'unverified'].contains(
                (metadata['license'] as String? ?? '').trim().toLowerCase(),
              ) ||
              (metadata['licenseUrl'] as String? ?? '').trim().isEmpty ||
              (metadata['source'] as String? ?? '').trim().isEmpty ||
              ((metadata['sourcePage'] as String? ?? '').trim().isEmpty &&
                  (metadata['source'] as String? ?? '').trim().toLowerCase() !=
                      'own work')) {
            blockers.add(
              '${entry.key}: replacement image lacks matching author and license evidence.',
            );
          }
          final thumbnail = metadata['thumbnailImagePath'] as String?;
          if (thumbnail != null &&
              (p.isAbsolute(thumbnail) ||
                  p.split(p.normalize(thumbnail)).contains('..') ||
                  !await File(p.join(base, thumbnail)).exists())) {
            blockers.add(
              '${entry.key}: replacement thumbnail is missing or unsafe.',
            );
          }
        } catch (_) {
          blockers.add(
            '${entry.key}: replacement image metadata cannot be read.',
          );
        }
      }
    }
    return blockers.toSet().toList();
  }
}
