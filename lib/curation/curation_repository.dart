import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../domain/curation/curation_issue.dart';
import '../domain/curation/place_addition.dart';
import '../domain/curation/place_exclusion.dart';
import '../domain/curation/place_override.dart';
import '../domain/curation/place_review.dart';

/// Reads and writes deterministic entity-level curation JSON files.
/// Stored in `assets/city_packs/<cityId>/curation/` for Git tracking.
class CurationRepository {
  static Directory? _overrideBaseDir;

  // In-memory web fallback stores
  static final Map<String, Map<String, PlaceOverride>> _webOverrides = {};
  static final Map<String, Map<String, PlaceAddition>> _webAdditions = {};
  static final Map<String, Map<String, PlaceExclusion>> _webExclusions = {};
  static final Map<String, Map<String, PlaceReview>> _webReviews = {};
  static final Map<String, Map<String, CurationIssue>> _webIssues = {};

  static void setOverrideDirectory(Directory? dir) {
    _overrideBaseDir = dir;
  }

  /// Locates the curation root directory for the given city.
  Future<Directory> _getCurationDir(String cityId) async {
    if (_overrideBaseDir != null) {
      final dir = Directory(p.join(_overrideBaseDir!.path, cityId, 'curation'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }

    // Try relative project assets path (standard local desktop / CLI environment)
    final localAssetDir = Directory(p.join('assets', 'city_packs', cityId, 'curation'));
    if (localAssetDir.existsSync()) {
      return localAssetDir;
    }

    // Check if assets/city_packs/<cityId> exists to initialize curation directory inside it
    final cityPackDir = Directory(p.join('assets', 'city_packs', cityId));
    if (cityPackDir.existsSync()) {
      localAssetDir.createSync(recursive: true);
      return localAssetDir;
    }

    // Fallback to ApplicationSupportDirectory for sandbox environments
    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      base = Directory(p.join(Directory.systemTemp.path, 'yatracanvas_curation'));
    }

    final dir = Directory(p.join(base.path, 'city_packs', cityId, 'curation'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> _getSubdir(String cityId, String subfolder) async {
    final root = await _getCurationDir(cityId);
    final dir = Directory(p.join(root.path, subfolder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ==========================================
  // Overrides
  // ==========================================

  Future<List<PlaceOverride>> loadOverrides(String cityId) async {
    if (kIsWeb) {
      return (_webOverrides[cityId] ?? {}).values.toList();
    }

    final dir = await _getSubdir(cityId, 'overrides');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final List<PlaceOverride> list = [];

    for (final f in files) {
      try {
        final content = await f.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        list.add(PlaceOverride.fromJson(map));
      } catch (e) {
        debugPrint('[WARN] Error reading override file ${f.path}: $e');
      }
    }
    return list;
  }

  Future<void> saveOverride(PlaceOverride override) async {
    if (kIsWeb) {
      _webOverrides.putIfAbsent(override.cityId, () => {})[override.placeId] = override;
      return;
    }

    final dir = await _getSubdir(override.cityId, 'overrides');
    final safeId = _sanitizeFilename(override.placeId);
    final file = File(p.join(dir.path, '$safeId.json'));
    await file.writeAsString(override.toFormattedJson(), flush: true);
  }

  Future<void> deleteOverride(String cityId, String placeId) async {
    if (kIsWeb) {
      _webOverrides[cityId]?.remove(placeId);
      return;
    }

    final dir = await _getSubdir(cityId, 'overrides');
    final safeId = _sanitizeFilename(placeId);
    final file = File(p.join(dir.path, '$safeId.json'));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  // ==========================================
  // Additions
  // ==========================================

  Future<List<PlaceAddition>> loadAdditions(String cityId) async {
    if (kIsWeb) {
      return (_webAdditions[cityId] ?? {}).values.toList();
    }

    final dir = await _getSubdir(cityId, 'additions');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final List<PlaceAddition> list = [];

    for (final f in files) {
      try {
        final content = await f.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        list.add(PlaceAddition.fromJson(map));
      } catch (e) {
        debugPrint('[WARN] Error reading addition file ${f.path}: $e');
      }
    }
    return list;
  }

  Future<void> saveAddition(PlaceAddition addition) async {
    if (kIsWeb) {
      _webAdditions.putIfAbsent(addition.cityId, () => {})[addition.id] = addition;
      return;
    }

    final dir = await _getSubdir(addition.cityId, 'additions');
    final safeId = _sanitizeFilename(addition.id);
    final file = File(p.join(dir.path, '$safeId.json'));
    await file.writeAsString(addition.toFormattedJson(), flush: true);
  }

  Future<void> deleteAddition(String cityId, String additionId) async {
    if (kIsWeb) {
      _webAdditions[cityId]?.remove(additionId);
      return;
    }

    final dir = await _getSubdir(cityId, 'additions');
    final safeId = _sanitizeFilename(additionId);
    final file = File(p.join(dir.path, '$safeId.json'));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  // ==========================================
  // Exclusions
  // ==========================================

  Future<List<PlaceExclusion>> loadExclusions(String cityId) async {
    if (kIsWeb) {
      return (_webExclusions[cityId] ?? {}).values.toList();
    }

    final dir = await _getSubdir(cityId, 'exclusions');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final List<PlaceExclusion> list = [];

    for (final f in files) {
      try {
        final content = await f.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        list.add(PlaceExclusion.fromJson(map));
      } catch (e) {
        debugPrint('[WARN] Error reading exclusion file ${f.path}: $e');
      }
    }
    return list;
  }

  Future<void> saveExclusion(PlaceExclusion exclusion) async {
    if (kIsWeb) {
      _webExclusions.putIfAbsent(exclusion.cityId, () => {})[exclusion.placeId] = exclusion;
      return;
    }

    final dir = await _getSubdir(exclusion.cityId, 'exclusions');
    final safeId = _sanitizeFilename(exclusion.placeId);
    final file = File(p.join(dir.path, '$safeId.json'));
    await file.writeAsString(exclusion.toFormattedJson(), flush: true);
  }

  Future<void> deleteExclusion(String cityId, String placeId) async {
    if (kIsWeb) {
      _webExclusions[cityId]?.remove(placeId);
      return;
    }

    final dir = await _getSubdir(cityId, 'exclusions');
    final safeId = _sanitizeFilename(placeId);
    final file = File(p.join(dir.path, '$safeId.json'));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  // ==========================================
  // Reviews (Manual QA Sample)
  // ==========================================

  Future<List<PlaceReview>> loadReviews(String cityId) async {
    if (kIsWeb) {
      return (_webReviews[cityId] ?? {}).values.toList();
    }

    final dir = await _getSubdir(cityId, 'reviews');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final List<PlaceReview> list = [];

    for (final f in files) {
      try {
        final content = await f.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        list.add(PlaceReview.fromJson(map));
      } catch (e) {
        debugPrint('[WARN] Error reading review file ${f.path}: $e');
      }
    }
    return list;
  }

  Future<void> saveReview(PlaceReview review) async {
    if (kIsWeb) {
      _webReviews.putIfAbsent(review.cityId, () => {})[review.placeId] = review;
      return;
    }

    final dir = await _getSubdir(review.cityId, 'reviews');
    final safeId = _sanitizeFilename(review.placeId);
    final file = File(p.join(dir.path, '$safeId.json'));
    await file.writeAsString(review.toFormattedJson(), flush: true);
  }

  // ==========================================
  // Issues Lifecycle
  // ==========================================

  Future<List<CurationIssue>> loadIssues(String cityId) async {
    if (kIsWeb) {
      return (_webIssues[cityId] ?? {}).values.toList();
    }

    final dir = await _getSubdir(cityId, 'issues');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final List<CurationIssue> list = [];

    for (final f in files) {
      try {
        final content = await f.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        list.add(CurationIssue.fromJson(map));
      } catch (e) {
        debugPrint('[WARN] Error reading issue file ${f.path}: $e');
      }
    }
    return list;
  }

  Future<void> saveIssue(CurationIssue issue) async {
    if (kIsWeb) {
      _webIssues.putIfAbsent(issue.cityId, () => {})[issue.id] = issue;
      return;
    }

    final dir = await _getSubdir(issue.cityId, 'issues');
    final safeId = _sanitizeFilename(issue.id);
    final file = File(p.join(dir.path, '$safeId.json'));
    await file.writeAsString(issue.toFormattedJson(), flush: true);
  }

  Future<void> deleteIssue(String cityId, String issueId) async {
    if (kIsWeb) {
      _webIssues[cityId]?.remove(issueId);
      return;
    }

    final dir = await _getSubdir(cityId, 'issues');
    final safeId = _sanitizeFilename(issueId);
    final file = File(p.join(dir.path, '$safeId.json'));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  String _sanitizeFilename(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
  }
}
