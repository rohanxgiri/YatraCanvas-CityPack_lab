/// lib/review/services/review_manifest_loader.dart
///
/// Loads and caches review_candidates.json for a given city.
/// Gracefully handles missing manifests, unknown reason codes, and schema
/// version mismatches.
///
/// RULES:
/// - Never writes to the source file.
/// - Never makes remote requests.
/// - Works offline once assets are synced.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/review_candidate.dart';

/// Holds the parsed manifest plus any load-time warnings.
class ReviewManifestResult {
  final List<ReviewCandidate> candidates;
  final String? error;
  final List<String> warnings;
  final bool isMissing;

  const ReviewManifestResult({
    this.candidates = const [],
    this.error,
    this.warnings = const [],
    this.isMissing = false,
  });

  bool get hasError => error != null;
  int get count => candidates.length;
}

class ReviewManifestLoader {
  /// Loads `assets/city_packs/<cityId>/review_candidates.json`.
  ///
  /// Tries the file system path first (desktop / CLI), then falls back to
  /// Flutter asset bundle (web / packaged app).
  Future<ReviewManifestResult> load(String cityId) async {
    // Desktop: try local file system path relative to project root
    if (!kIsWeb) {
      final localPath = p.join(
        'assets',
        'city_packs',
        cityId,
        'review_candidates.json',
      );
      final file = File(localPath);
      if (file.existsSync()) {
        return _parseFile(await file.readAsString(), cityId);
      }
    }

    // Asset bundle fallback (web / release mode)
    try {
      final assetPath =
          'assets/city_packs/$cityId/review_candidates.json';
      final raw = await rootBundle.loadString(assetPath);
      return _parseFile(raw, cityId);
    } on FlutterError {
      // Asset not registered — manifest is missing
      return const ReviewManifestResult(
        isMissing: true,
        warnings: [
          'review_candidates.json not found. '
              'Run: python tools/sync_city_packs.py --cities <city>',
        ],
      );
    } catch (e) {
      return ReviewManifestResult(
        error: 'Failed to load review manifest: $e',
      );
    }
  }

  /// Public entry point for unit tests — parses a raw JSON string.
  /// Do not use in production code; call [load] instead.
  ReviewManifestResult parseRawForTest(String raw, String cityId) =>
      _parseFile(raw, cityId);

  ReviewManifestResult _parseFile(String raw, String cityId) {
    final warnings = <String>[];
    List<dynamic> list;

    try {
      list = json.decode(raw) as List<dynamic>;
    } catch (e) {
      return ReviewManifestResult(
        error: 'review_candidates.json is not valid JSON: $e',
      );
    }

    final candidates = <ReviewCandidate>[];
    int malformed = 0;

    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        malformed++;
        continue;
      }
      try {
        candidates.add(ReviewCandidate.fromJson(item));
      } catch (e) {
        malformed++;
        debugPrint('[ReviewManifestLoader] Skipped malformed candidate: $e');
      }
    }

    if (malformed > 0) {
      warnings.add('$malformed malformed candidate(s) skipped.');
    }

    return ReviewManifestResult(
      candidates: candidates,
      warnings: warnings,
    );
  }

  /// Sorts candidates into the recommended inbox order.
  ///
  /// Order: HIGH priority first, then by confidence proximity to 0.5
  /// (most uncertain first), then by tier importance.
  static List<ReviewCandidate> sortForInbox(
      List<ReviewCandidate> candidates) {
    final sorted = List<ReviewCandidate>.from(candidates);
    sorted.sort((a, b) {
      // 1. Priority (HIGH before MEDIUM before LOW)
      final pCmp =
          a.reviewPriority.sortOrder.compareTo(b.reviewPriority.sortOrder);
      if (pCmp != 0) return pCmp;

      // 2. Tier importance (core > recommended > discovery > support)
      final tierOrder = _tierOrder(a.tier).compareTo(_tierOrder(b.tier));
      if (tierOrder != 0) return tierOrder;

      // 3. Closest to decision threshold (confidence closest to 0.5)
      final aDist = (a.confidence - 0.5).abs();
      final bDist = (b.confidence - 0.5).abs();
      return aDist.compareTo(bDist);
    });
    return sorted;
  }

  static int _tierOrder(String tier) {
    switch (tier) {
      case 'core_destination':
        return 0;
      case 'recommended':
        return 1;
      case 'discovery':
        return 2;
      case 'support':
        return 3;
      default:
        return 4;
    }
  }
}
