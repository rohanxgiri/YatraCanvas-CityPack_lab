/// lib/review/repository/inbox_decision_repository.dart
///
/// Reads and writes InboxDecision records for DataFactory review candidates.
///
/// Storage: `assets/city_packs/<city>/curation/inbox_decisions/<canonical_id>.json`
/// This mirrors the CurationRepository pattern so all human decisions are
/// git-trackable, diffable, and versionable.
///
/// RULES:
/// - Never writes to the DataFactory source files.
/// - Each decision is a separate file for clean git diffs.
/// - Supports remove (undo) to restore DataFactory source behaviour.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/inbox_decision.dart';
import '../models/review_candidate.dart';

class InboxDecisionRepository {
  final List<String> loadWarnings = [];
  /// Only evidence used to judge the place, never fetch timestamps or ordering.
  static Map<String, dynamic> semanticFieldsOf(ReviewCandidate c) => {
    'name': c.name,
    'category': c.category,
    'subcategory': c.subcategory,
    'tier': c.tier,
    'latitude': c.latitude,
    'longitude': c.longitude,
    'wikidata_id': c.wikidataId,
    'commons_image': c.commonsImage,
    'wikidata_p18': c.wikidataP18,
    'external_ids': {
      for (final key in c.externalIds.keys.toList()..sort())
        key: c.externalIds[key]!.toSet().toList()..sort(),
    },
    'osm_tags': {
      for (final key in [
        'amenity',
        'building',
        'tourism',
        'historic',
        'religion',
        'denomination',
        'shop',
        'leisure',
        'name',
        'wikidata',
      ])
        if (c.osmTags.containsKey(key)) key: c.osmTags[key],
    },
  };
  static Directory? _overrideBaseDir;

  // Web in-memory fallback
  static final Map<String, Map<String, InboxDecision>> _webStore = {};

  static void setOverrideDirectory(Directory? dir) {
    _overrideBaseDir = dir;
  }

  Future<Directory> _getDecisionDir(String cityId) async {
    if (_overrideBaseDir != null) {
      final dir = Directory(
        p.join(_overrideBaseDir!.path, cityId, 'curation', 'inbox_decisions'),
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }

    final localDir = Directory(
      p.join('assets', 'city_packs', cityId, 'curation', 'inbox_decisions'),
    );
    if (localDir.existsSync()) return localDir;

    final cityPackDir = Directory(p.join('assets', 'city_packs', cityId));
    if (cityPackDir.existsSync()) {
      localDir.createSync(recursive: true);
      return localDir;
    }

    // Fallback to ApplicationSupportDirectory
    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      base = Directory(
        p.join(Directory.systemTemp.path, 'yatracanvas_curation'),
      );
    }
    final dir = Directory(
      p.join(base.path, 'city_packs', cityId, 'curation', 'inbox_decisions'),
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Loads all persisted decisions for a city.
  Future<Map<String, InboxDecision>> loadDecisions(String cityId) async {
    loadWarnings.clear();
    if (kIsWeb) {
      return Map.from(_webStore[cityId] ?? {});
    }

    final dir = await _getDecisionDir(cityId);
    final result = <String, InboxDecision>{};

    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        final content = await file.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        final decision = InboxDecision.fromJson(map);
        result[decision.canonicalId] = decision;
      } catch (e) {
        loadWarnings.add('Saved decision ${p.basename(file.path)} is corrupt. Restore it from Git or re-review the candidate.');
        debugPrint('[InboxDecisionRepo] Error reading ${file.path}: $e');
      }
    }

    return result;
  }

  /// Saves a single decision. Replaces any existing decision for the same
  /// canonical ID.
  Future<void> saveDecision(InboxDecision decision) async {
    if (kIsWeb) {
      _webStore.putIfAbsent(decision.cityId, () => {})[decision.canonicalId] =
          decision;
      return;
    }

    final dir = await _getDecisionDir(decision.cityId);
    final safeId = _sanitize(decision.canonicalId);
    final file = File(p.join(dir.path, '$safeId.json'));
    await file.writeAsString(decision.toFormattedJson(), flush: true);
  }

  /// Removes a decision, restoring DataFactory source behaviour for this
  /// candidate.
  Future<void> removeDecision(String cityId, String canonicalId) async {
    if (kIsWeb) {
      _webStore[cityId]?.remove(canonicalId);
      return;
    }

    final dir = await _getDecisionDir(cityId);
    final safeId = _sanitize(canonicalId);
    final file = File(p.join(dir.path, '$safeId.json'));
    if (file.existsSync()) await file.delete();
  }

  /// Compares a freshly loaded candidate against an existing decision's
  /// snapshot to detect "changed since review".
  InboxDecision? detectChanges({
    required InboxDecision existing,
    required ReviewCandidate fresh,
  }) {
    if (existing.verdict == InboxVerdict.unreviewed) return null;

    final snap = existing.snapshot;
    final changed = <String>[];

    final previous = snap.semanticFields;
    if (previous != null) {
      final current = semanticFieldsOf(fresh);
      for (final key in current.keys) {
        final before = previous[key];
        final after = current[key];
        if (key == 'latitude' || key == 'longitude') {
          // Approximately 50 metres, noise below this does not require review.
          if (before is num &&
              after is num &&
              (before - after).abs() <= 0.0005) {
            continue;
          }
        }
        if (!mapEquals(
              previous['osm_tags'] as Map?,
              current['osm_tags'] as Map?,
            ) &&
            key == 'osm_tags') {
          changed.add('OSM place meaning changed');
        } else if (key != 'osm_tags' &&
            jsonEncode(before) != jsonEncode(after)) {
          changed.add('$key changed');
        }
      }
    }
    if ((snap.confidence - fresh.confidence).abs() > 0.05) {
      changed.add('confidence changed');
    }

    if (snap.travelRelevanceReason != fresh.travelRelevanceReason) {
      changed.add(
        'reason: ${snap.travelRelevanceReason} → ${fresh.travelRelevanceReason}',
      );
    }
    if ((snap.travelRelevanceScore - fresh.travelRelevanceScore).abs() > 0.05) {
      changed.add(
        'score: ${snap.travelRelevanceScore.toStringAsFixed(2)} → '
        '${fresh.travelRelevanceScore.toStringAsFixed(2)}',
      );
    }
    if (snap.suggestedAction != fresh.suggestedAction) {
      changed.add(
        'suggested action: ${snap.suggestedAction} → ${fresh.suggestedAction}',
      );
    }

    // Check if previously missing fields are now present
    final newlyPresent = snap.missingFields
        .where((f) => !fresh.missingFields.contains(f))
        .toList();
    if (newlyPresent.isNotEmpty) {
      changed.add('now has: ${newlyPresent.join(', ')}');
    }
    final newlyMissing = fresh.missingFields
        .where((f) => !snap.missingFields.contains(f))
        .toList();
    if (newlyMissing.isNotEmpty) {
      changed.add('now missing: ${newlyMissing.join(', ')}');
    }

    if (changed.isEmpty) return null;

    return existing.copyWith(
      changedSinceReview: true,
      changedFields: changed.join('\n'),
    );
  }

  String _sanitize(String id) =>
      id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
}
