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
import '../models/identity_conflict.dart';
import '../models/inbox_decision.dart';
import '../repository/inbox_decision_repository.dart';

/// Holds the parsed manifest plus any load-time warnings.
class ReviewManifestResult {
  final List<ReviewCandidate> candidates;
  final String? error;
  final List<String> warnings;
  final bool isMissing;
  final List<IdentityConflict> conflicts;

  const ReviewManifestResult({
    this.candidates = const [],
    this.error,
    this.warnings = const [],
    this.isMissing = false,
    this.conflicts = const [],
  });

  bool get hasError => error != null;
  int get count => candidates.length;
}

class ReviewManifestLoader {
  /// Loads `assets/city_packs/<cityId>/review_candidates.json`.
  ///
  /// Tries the file system path first (desktop / CLI), then falls back to
  /// Flutter asset bundle (web / packaged app).
  Future<ReviewManifestResult> load(
    String cityId, {
    Set<String> publishedIds = const {},
  }) async {
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
        try {
          return await _applyResolutions(
            _parseFile(
              await file.readAsString(),
              cityId,
              publishedIds: publishedIds,
            ),
            cityId,
          );
        } catch (e) {
          return ReviewManifestResult(
            error:
                'Review manifest cannot be read: $e. Verify the source and refresh city data.',
          );
        }
      }
    }

    // Asset bundle fallback (web / release mode)
    try {
      final assetPath = 'assets/city_packs/$cityId/review_candidates.json';
      final raw = await rootBundle.loadString(assetPath);
      return _parseFile(raw, cityId, publishedIds: publishedIds);
    } on FlutterError {
      // Asset not registered — manifest is missing
      return const ReviewManifestResult(
        isMissing: true,
        warnings: [
          'review_candidates.json not found. '
              'Use Sync Latest City Packs to refresh this city from DataFactory.',
        ],
      );
    } catch (e) {
      return ReviewManifestResult(error: 'Failed to load review manifest: $e');
    }
  }

  /// Public entry point for unit tests — parses a raw JSON string.
  /// Do not use in production code; call [load] instead.
  ReviewManifestResult parseRawForTest(String raw, String cityId) =>
      _parseFile(raw, cityId);

  ReviewManifestResult _parseFile(
    String raw,
    String cityId, {
    Set<String> publishedIds = const {},
  }) {
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
    final ids = <String>{};
    final collisions = <String>{};
    final grouped = <String, List<ReviewCandidate>>{};
    final rawGrouped = <String, List<Map<String, dynamic>>>{};
    int malformed = 0;

    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        malformed++;
        continue;
      }
      try {
        if (item['schema_version'] != null && item['schema_version'] != '3.0') {
          return ReviewManifestResult(
            error:
                'Unsupported review schema ${item['schema_version']}. Sync a supported v3 pack.',
          );
        }
        final candidate = ReviewCandidate.fromJson(
          item,
          isPublished: publishedIds.contains(
            item['canonical_id'] ?? item['place_id'],
          ),
        );
        grouped.putIfAbsent(candidate.canonicalId, () => []).add(candidate);
        rawGrouped.putIfAbsent(candidate.canonicalId, () => []).add(item);
        if (!ids.add(candidate.canonicalId)) {
          collisions.add(candidate.canonicalId);
        } else {
          candidates.add(candidate);
        }
      } catch (e) {
        malformed++;
        debugPrint('[ReviewManifestLoader] Skipped malformed candidate: $e');
      }
    }

    if (malformed > 0) {
      warnings.add('$malformed malformed candidate(s) skipped.');
    }
    if (collisions.isNotEmpty) {
      // A canonical ID owns one decision. Do not let that decision accidentally
      // approve several different source records with a colliding ID.
      candidates.removeWhere((c) => collisions.contains(c.canonicalId));
      warnings.add(
        '${collisions.length} conflicting canonical IDs withheld. '
        'Repair duplicate identities in DataFactory and sync again.',
      );
    }

    return ReviewManifestResult(
      candidates: candidates,
      warnings: warnings,
      conflicts: [
        for (final id in collisions)
          IdentityConflict(
            canonicalId: id,
            members: grouped[id]!,
            rawMembers: rawGrouped[id]!,
          ),
      ],
    );
  }

  Future<ReviewManifestResult> _applyResolutions(
    ReviewManifestResult result,
    String cityId,
  ) async {
    final conflicts = <IdentityConflict>[];
    final candidates = [...result.candidates];
    for (final group in result.conflicts) {
      bool resolved = false;
      bool changed = false;
      final path = File(
        p.join(
          'assets',
          'city_packs',
          cityId,
          'curation',
          'identity_conflicts',
          '${group.fileId}.json',
        ),
      );
      if (await path.exists()) {
        try {
          final record =
              jsonDecode(await path.readAsString()) as Map<String, dynamic>;
          final snapshots = record['members'] as Map<String, dynamic>;
          final freshIds = group.members.map(conflictMemberId).toSet();
          changed =
              snapshots.keys.toSet().difference(freshIds).isNotEmpty ||
              freshIds.difference(snapshots.keys.toSet()).isNotEmpty;
          for (final member in group.members) {
            final snapshot = snapshots[conflictMemberId(member)];
            if (snapshot == null) {
              changed = true;
              continue;
            }
            final previous = InboxDecision(
              canonicalId: group.canonicalId,
              cityId: cityId,
              packVersion: '',
              verdict: InboxVerdict.approved,
              author: record['author'] as String,
              decidedAt: record['decided_at'] as String,
              snapshot: InboxDecisionSnapshot.fromJson(
                snapshot as Map<String, dynamic>,
              ),
            );
            if (InboxDecisionRepository().detectChanges(
                  existing: previous,
                  fresh: member,
                ) !=
                null) {
              changed = true;
            }
          }
          final action = record['action'];
          resolved =
              !changed &&
              !group.affectsPublished &&
              (record['author'] as String? ?? '').trim().isNotEmpty &&
              (record['notes'] as String? ?? '').trim().isNotEmpty &&
              (record['decided_at'] as String? ?? '').trim().isNotEmpty &&
              const {'merge', 'separate', 'exclude'}.contains(action);
          if (freshIds.length != group.members.length) resolved = false;
          if (resolved && action != 'exclude') {
            for (var i = 0; i < group.members.length; i++) {
              final member = group.members[i];
              if (action == 'merge' &&
                  conflictMemberId(member) != record['survivor']) {
                continue;
              }
              candidates.add(
                ReviewCandidate.fromJson({
                  ...group.rawMembers[i],
                  'canonical_id': action == 'separate'
                      ? '${group.canonicalId}__${conflictMemberId(member)}'
                      : group.canonicalId,
                }),
              );
              if (action == 'merge') break;
            }
            if (action == 'merge' && !freshIds.contains(record['survivor'])) {
              resolved = false;
            }
          }
        } catch (_) {
          changed = true;
        }
      }
      conflicts.add(
        IdentityConflict(
          canonicalId: group.canonicalId,
          members: group.members,
          rawMembers: group.rawMembers,
          resolved: resolved,
          changed: changed,
        ),
      );
    }
    final unresolved = conflicts.where((c) => !c.resolved).length;
    return ReviewManifestResult(
      candidates: candidates,
      conflicts: conflicts,
      error: result.error,
      isMissing: result.isMissing,
      warnings: [
        ...result.warnings.where(
          (w) => !w.contains('conflicting canonical IDs'),
        ),
        if (unresolved > 0)
          '$unresolved unresolved identity conflicts. Open Identity Conflicts to inspect and resolve them.',
      ],
    );
  }

  /// Sorts candidates into the recommended inbox order.
  ///
  /// Order: HIGH priority first, then by confidence proximity to 0.5
  /// (most uncertain first), then by tier importance.
  static List<ReviewCandidate> sortForInbox(List<ReviewCandidate> candidates) {
    final sorted = List<ReviewCandidate>.from(candidates);
    sorted.sort((a, b) {
      // 1. Priority (HIGH before MEDIUM before LOW)
      final pCmp = a.reviewPriority.sortOrder.compareTo(
        b.reviewPriority.sortOrder,
      );
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
