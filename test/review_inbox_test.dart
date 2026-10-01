/// test/review_inbox_test.dart
///
/// Tests for the Review Inbox system:
/// - Review manifest parsing (valid, missing optional fields, unknown reason codes,
///   malformed candidates)
/// - Filtering and sorting logic
/// - InboxDecision persistence model
/// - Changed-since-review detection
/// - Reason code translation
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:yatracanvas_citypack_lab/review/models/review_candidate.dart';
import 'package:yatracanvas_citypack_lab/review/models/inbox_decision.dart';
import 'package:yatracanvas_citypack_lab/review/services/review_manifest_loader.dart';
import 'package:yatracanvas_citypack_lab/review/services/review_reason_translator.dart';
import 'package:yatracanvas_citypack_lab/review/repository/inbox_decision_repository.dart';

// ── Shared fixture data ───────────────────────────────────────────────────────

Map<String, dynamic> _validCandidate({
  String canonicalId = 'yc_test_cafe',
  String name = 'Test Cafe',
  String category = 'cafe',
  String tier = 'recommended',
  double confidence = 0.85,
  String priority = 'HIGH',
  String reason = 'CONTRADICTORY_BUILDING_AMENITY',
  String action = 'VERIFY_AMENITY_SIGNIFICANCE',
  List<String> missingFields = const ['primary_image', 'opening_hours'],
}) {
  return {
    'canonical_id': canonicalId,
    'name': name,
    'name_en': name,
    'name_hi': null,
    'alternate_names': ['Test Coffee'],
    'alternate_name_records': [],
    'latitude': 26.9124,
    'longitude': 75.7873,
    'category': category,
    'subcategory': 'coffee_shop',
    'category_votes': [],
    'tier': tier,
    'address': null,
    'website': null,
    'phone': null,
    'email': null,
    'opening_hours': null,
    'opening_hours_source': null,
    'wikidata_id': null,
    'wikipedia_url': null,
    'wikidata_p18': null,
    'commons_image': null,
    'commons_category': null,
    'prose': null,
    'tags': ['cafe'],
    'osm_tags': {'amenity': 'cafe', 'building': 'house'},
    'external_ids': {
      'openstreetmap_ids': ['node/12345']
    },
    'sources_provenance': [
      {'source': 'openstreetmap', 'source_id': 'node/12345'}
    ],
    'source_count': 1,
    'confidence': confidence,
    'relevance_stage1': 'SECONDARY_TRAVEL_CANDIDATE',
    'relevance_reason1': 'OSM_AMENITY_CAFE',
    'review_priority': priority,
    'suggested_action': action,
    'travel_relevance_decision': 'REVIEW',
    'travel_relevance_reason': reason,
    'travel_relevance_score': 0.5,
    'travel_relevance_evidence': {
      'building': 'house',
      'travel_signals': ['Multi-provider'],
      'travel_points': 2,
    },
    'missing_fields': missingFields,
  };
}

// ── ReviewCandidate model tests ───────────────────────────────────────────────

void main() {
  group('ReviewCandidate.fromJson', () {
    test('parses a valid full candidate', () {
      final json = _validCandidate();
      final candidate = ReviewCandidate.fromJson(json);

      expect(candidate.canonicalId, 'yc_test_cafe');
      expect(candidate.name, 'Test Cafe');
      expect(candidate.category, 'cafe');
      expect(candidate.subcategory, 'coffee_shop');
      expect(candidate.tier, 'recommended');
      expect(candidate.confidence, closeTo(0.85, 0.001));
      expect(candidate.reviewPriority, ReviewPriority.high);
      expect(candidate.travelRelevanceReason, 'CONTRADICTORY_BUILDING_AMENITY');
      expect(candidate.suggestedAction, 'VERIFY_AMENITY_SIGNIFICANCE');
      expect(candidate.missingFields, containsAll(['primary_image', 'opening_hours']));
      expect(candidate.sourceCount, 1);
    });

    test('handles missing optional fields gracefully', () {
      // Only the minimum required fields
      final minJson = {
        'canonical_id': 'min_candidate',
        'name': 'Minimal Place',
        'latitude': 26.0,
        'longitude': 75.0,
        'category': 'heritage',
        'tier': 'discovery',
        'confidence': 0.6,
        'review_priority': 'LOW',
        'suggested_action': 'APPROVE_AS_SECONDARY_DESTINATION',
        'travel_relevance_decision': 'REVIEW',
        'travel_relevance_reason': 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
        'travel_relevance_score': 0.4,
      };

      final candidate = ReviewCandidate.fromJson(minJson);
      expect(candidate.canonicalId, 'min_candidate');
      expect(candidate.alternateNames, isEmpty);
      expect(candidate.categoryVotes, isEmpty);
      expect(candidate.missingFields, isEmpty);
      expect(candidate.osmTags, isEmpty);
      expect(candidate.tags, isEmpty);
      expect(candidate.sourcesProvenance, isEmpty);
      expect(candidate.reviewPriority, ReviewPriority.low);
    });

    test('falls back to name+coords for canonical_id when missing', () {
      final jsonNoId = Map<String, dynamic>.from(_validCandidate());
      jsonNoId.remove('canonical_id');

      final candidate = ReviewCandidate.fromJson(jsonNoId);
      // Fallback canonical_id is constructed from name_latitude_longitude
      expect(candidate.canonicalId, isNotEmpty);
    });

    test('maps priority string to enum correctly', () {
      expect(
        ReviewCandidate.fromJson(_validCandidate(priority: 'HIGH')).reviewPriority,
        ReviewPriority.high,
      );
      expect(
        ReviewCandidate.fromJson(_validCandidate(priority: 'MEDIUM')).reviewPriority,
        ReviewPriority.medium,
      );
      expect(
        ReviewCandidate.fromJson(_validCandidate(priority: 'LOW')).reviewPriority,
        ReviewPriority.low,
      );
      // Unknown priority falls back to low
      expect(
        ReviewCandidate.fromJson(_validCandidate(priority: 'CRITICAL')).reviewPriority,
        ReviewPriority.low,
      );
    });

    test('hasImage is false when primary_image is in missing_fields', () {
      final c = ReviewCandidate.fromJson(
          _validCandidate(missingFields: ['primary_image']));
      expect(c.hasImage, isFalse);
    });

    test('hasImage is true when primary_image is NOT in missing_fields', () {
      final c = ReviewCandidate.fromJson(
          _validCandidate(missingFields: ['opening_hours']));
      expect(c.hasImage, isTrue);
    });
  });

  // ── ReviewManifestLoader sorting tests ───────────────────────────────────

  group('ReviewManifestLoader.sortForInbox', () {
    test('HIGH priority comes before MEDIUM and LOW', () {
      final candidates = [
        ReviewCandidate.fromJson(_validCandidate(
            canonicalId: 'low', priority: 'LOW', confidence: 0.5)),
        ReviewCandidate.fromJson(_validCandidate(
            canonicalId: 'high', priority: 'HIGH', confidence: 0.5)),
        ReviewCandidate.fromJson(_validCandidate(
            canonicalId: 'med', priority: 'MEDIUM', confidence: 0.5)),
      ];

      final sorted = ReviewManifestLoader.sortForInbox(candidates);
      expect(sorted[0].canonicalId, 'high');
      expect(sorted[1].canonicalId, 'med');
      expect(sorted[2].canonicalId, 'low');
    });

    test('core_destination tier comes before recommended within same priority', () {
      final candidates = [
        ReviewCandidate.fromJson(_validCandidate(
            canonicalId: 'rec', tier: 'recommended', priority: 'HIGH')),
        ReviewCandidate.fromJson(_validCandidate(
            canonicalId: 'core', tier: 'core_destination', priority: 'HIGH')),
      ];

      final sorted = ReviewManifestLoader.sortForInbox(candidates);
      expect(sorted[0].canonicalId, 'core');
      expect(sorted[1].canonicalId, 'rec');
    });

    test('within same priority and tier, closer-to-threshold confidence comes first', () {
      final candidates = [
        ReviewCandidate.fromJson(_validCandidate(
            canonicalId: 'far', confidence: 0.9, priority: 'HIGH')),
        ReviewCandidate.fromJson(_validCandidate(
            canonicalId: 'near', confidence: 0.55, priority: 'HIGH')),
      ];

      final sorted = ReviewManifestLoader.sortForInbox(candidates);
      expect(sorted[0].canonicalId, 'near');
      expect(sorted[1].canonicalId, 'far');
    });
  });

  // ── ReviewManifestLoader._parseFile tests ──────────────────────────────

  group('ReviewManifestLoader (parsing)', () {
    final loader = ReviewManifestLoader();

    test('parses valid JSON list', () {
      final raw = '[${_toJson(_validCandidate())},${_toJson(_validCandidate(canonicalId: "c2", name: "Place 2"))}]';
      final result = loader.parseRawForTest(raw, 'jaipur');

      expect(result.hasError, isFalse);
      expect(result.candidates, hasLength(2));
      expect(result.warnings, isEmpty);
    });

    test('returns error for invalid JSON', () {
      final result = loader.parseRawForTest('not json', 'jaipur');
      expect(result.hasError, isTrue);
    });

    test('skips malformed candidates and warns', () {
      final raw = '[${_toJson(_validCandidate())}, "not an object", null]';
      final result = loader.parseRawForTest(raw, 'jaipur');

      expect(result.hasError, isFalse);
      expect(result.candidates, hasLength(1)); // Only the valid one
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('malformed'));
    });

    test('handles empty list without error', () {
      final result = loader.parseRawForTest('[]', 'jaipur');
      expect(result.hasError, isFalse);
      expect(result.candidates, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });

  // ── InboxDecision model tests ────────────────────────────────────────────

  group('InboxDecision', () {
    test('serializes and deserializes correctly', () {
      final decision = InboxDecision(
        canonicalId: 'test_id',
        cityId: 'jaipur',
        packVersion: 'v3',
        verdict: InboxVerdict.approved,
        verdictNote: 'Looks good',
        author: 'alice',
        decidedAt: '2026-10-01T10:00:00Z',
        snapshot: const InboxDecisionSnapshot(
          travelRelevanceReason: 'CONTRADICTORY_BUILDING_AMENITY',
          travelRelevanceScore: 0.5,
          confidence: 0.85,
          suggestedAction: 'VERIFY_AMENITY_SIGNIFICANCE',
          missingFields: ['primary_image'],
        ),
      );

      final json = decision.toJson();
      final restored = InboxDecision.fromJson(json);

      expect(restored.canonicalId, 'test_id');
      expect(restored.verdict, InboxVerdict.approved);
      expect(restored.verdictNote, 'Looks good');
      expect(restored.author, 'alice');
      expect(restored.snapshot.travelRelevanceReason,
          'CONTRADICTORY_BUILDING_AMENITY');
      expect(restored.snapshot.missingFields, contains('primary_image'));
    });

    test('unreviewed verdict is not resolved', () {
      final d = InboxDecision(
        canonicalId: 'x',
        cityId: 'jaipur',
        packVersion: 'v3',
        verdict: InboxVerdict.unreviewed,
        author: 'a',
        decidedAt: '2026-10-01T00:00:00Z',
        snapshot: const InboxDecisionSnapshot(
          travelRelevanceReason: 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
          travelRelevanceScore: 0.4,
          confidence: 0.7,
          suggestedAction: 'APPROVE_AS_SECONDARY_DESTINATION',
        ),
      );
      expect(d.isResolved, isFalse);
    });

    test('approved verdict is resolved', () {
      final d = InboxDecision(
        canonicalId: 'x',
        cityId: 'jaipur',
        packVersion: 'v3',
        verdict: InboxVerdict.approved,
        author: 'a',
        decidedAt: '2026-10-01T00:00:00Z',
        snapshot: const InboxDecisionSnapshot(
          travelRelevanceReason: 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
          travelRelevanceScore: 0.4,
          confidence: 0.7,
          suggestedAction: 'APPROVE_AS_SECONDARY_DESTINATION',
        ),
      );
      expect(d.isResolved, isTrue);
    });

    test('rejected verdict is resolved', () {
      final d = InboxDecision(
        canonicalId: 'x',
        cityId: 'jaipur',
        packVersion: 'v3',
        verdict: InboxVerdict.rejected,
        author: 'a',
        decidedAt: '2026-10-01T00:00:00Z',
        snapshot: const InboxDecisionSnapshot(
          travelRelevanceReason: 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
          travelRelevanceScore: 0.4,
          confidence: 0.7,
          suggestedAction: 'APPROVE_AS_SECONDARY_DESTINATION',
        ),
      );
      expect(d.isResolved, isTrue);
    });

    test('needs_research verdict is NOT resolved', () {
      final d = InboxDecision(
        canonicalId: 'x',
        cityId: 'jaipur',
        packVersion: 'v3',
        verdict: InboxVerdict.needsResearch,
        author: 'a',
        decidedAt: '2026-10-01T00:00:00Z',
        snapshot: const InboxDecisionSnapshot(
          travelRelevanceReason: 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
          travelRelevanceScore: 0.4,
          confidence: 0.7,
          suggestedAction: 'APPROVE_AS_SECONDARY_DESTINATION',
        ),
      );
      expect(d.isResolved, isFalse);
    });
  });

  // ── Changed-since-review detection ──────────────────────────────────────

  group('InboxDecisionRepository.detectChanges', () {
    final repo = InboxDecisionRepository();

    InboxDecision makeDecision(InboxDecisionSnapshot snapshot) => InboxDecision(
          canonicalId: 'test_place',
          cityId: 'jaipur',
          packVersion: 'v3',
          verdict: InboxVerdict.approved,
          author: 'alice',
          decidedAt: '2026-10-01T00:00:00Z',
          snapshot: snapshot,
        );

    ReviewCandidate makeFreshCandidate({
      String reason = 'CONTRADICTORY_BUILDING_AMENITY',
      double score = 0.5,
      double confidence = 0.85,
      String action = 'VERIFY_AMENITY_SIGNIFICANCE',
      List<String> missingFields = const [],
    }) {
      return ReviewCandidate.fromJson(_validCandidate(
        reason: reason,
        confidence: confidence,
        action: action,
        missingFields: missingFields,
      ));
    }

    test('returns null when nothing meaningful changed', () {
      final existing = makeDecision(const InboxDecisionSnapshot(
        travelRelevanceReason: 'CONTRADICTORY_BUILDING_AMENITY',
        travelRelevanceScore: 0.5,
        confidence: 0.85,
        suggestedAction: 'VERIFY_AMENITY_SIGNIFICANCE',
        missingFields: [],
      ));

      final fresh = makeFreshCandidate();
      final result =
          repo.detectChanges(existing: existing, fresh: fresh);
      expect(result, isNull);
    });

    test('detects reason code change', () {
      final existing = makeDecision(const InboxDecisionSnapshot(
        travelRelevanceReason: 'CONTRADICTORY_BUILDING_AMENITY',
        travelRelevanceScore: 0.5,
        confidence: 0.85,
        suggestedAction: 'VERIFY_AMENITY_SIGNIFICANCE',
      ));

      final fresh = makeFreshCandidate(
          reason: 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
          action: 'APPROVE_AS_SECONDARY_DESTINATION');
      final result =
          repo.detectChanges(existing: existing, fresh: fresh);

      expect(result, isNotNull);
      expect(result!.changedSinceReview, isTrue);
      expect(result.changedFields, contains('reason'));
    });

    test('detects significant score change', () {
      final existing = makeDecision(const InboxDecisionSnapshot(
        travelRelevanceReason: 'CONTRADICTORY_BUILDING_AMENITY',
        travelRelevanceScore: 0.3,
        confidence: 0.85,
        suggestedAction: 'VERIFY_AMENITY_SIGNIFICANCE',
      ));

      final fresh = makeFreshCandidate(score: 0.8);
      final result =
          repo.detectChanges(existing: existing, fresh: fresh);

      expect(result, isNotNull);
      expect(result!.changedSinceReview, isTrue);
      expect(result.changedFields, contains('score'));
    });

    test('does not flag tiny score variation as changed', () {
      final existing = makeDecision(const InboxDecisionSnapshot(
        travelRelevanceReason: 'CONTRADICTORY_BUILDING_AMENITY',
        travelRelevanceScore: 0.500,
        confidence: 0.85,
        suggestedAction: 'VERIFY_AMENITY_SIGNIFICANCE',
      ));

      final fresh = makeFreshCandidate(score: 0.503);
      final result =
          repo.detectChanges(existing: existing, fresh: fresh);

      // Difference < 0.05 threshold, should not flag as changed
      expect(result, isNull);
    });

    test('does not run detectChanges on UNREVIEWED decisions', () {
      final existing = InboxDecision(
        canonicalId: 'test_place',
        cityId: 'jaipur',
        packVersion: 'v3',
        verdict: InboxVerdict.unreviewed,
        author: 'alice',
        decidedAt: '2026-10-01T00:00:00Z',
        snapshot: const InboxDecisionSnapshot(
          travelRelevanceReason: 'CONTRADICTORY_BUILDING_AMENITY',
          travelRelevanceScore: 0.5,
          confidence: 0.85,
          suggestedAction: 'VERIFY_AMENITY_SIGNIFICANCE',
        ),
      );

      final fresh = makeFreshCandidate(reason: 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT');
      final result = repo.detectChanges(existing: existing, fresh: fresh);
      // Should be null for UNREVIEWED — no change to detect
      expect(result, isNull);
    });

    test('detects newly present field in fresh candidate', () {
      final existing = makeDecision(const InboxDecisionSnapshot(
        travelRelevanceReason: 'CONTRADICTORY_BUILDING_AMENITY',
        travelRelevanceScore: 0.5,
        confidence: 0.85,
        suggestedAction: 'VERIFY_AMENITY_SIGNIFICANCE',
        missingFields: ['primary_image', 'opening_hours'],
      ));

      // Fresh candidate now has hours (no longer missing)
      final fresh = makeFreshCandidate(missingFields: ['primary_image']);
      final result = repo.detectChanges(existing: existing, fresh: fresh);

      expect(result, isNotNull);
      expect(result!.changedFields, contains('now has'));
    });
  });

  // ── Reason code translation tests ────────────────────────────────────────

  group('ReviewReasonTranslator', () {
    test('translates known reason codes', () {
      final t = ReviewReasonTranslator.translateReason(
          'CONTRADICTORY_BUILDING_AMENITY');
      expect(t.title, isNotEmpty);
      expect(t.description, isNotEmpty);
      expect(t.isCritical, isTrue);
    });

    test('translates SECONDARY_COMMERCIAL_REQUIRES_AUDIT', () {
      final t = ReviewReasonTranslator.translateReason(
          'SECONDARY_COMMERCIAL_REQUIRES_AUDIT');
      expect(t.title, isNotEmpty);
      expect(t.isCritical, isFalse);
    });

    test('returns safe fallback for unknown reason codes', () {
      final t = ReviewReasonTranslator.translateReason(
          'SOME_FUTURE_REASON_CODE_2027');
      expect(t.code, 'UNKNOWN');
      expect(t.title, isNotEmpty);
      expect(t.description, isNotEmpty);
    });

    test('translates known suggested actions', () {
      final a = ReviewReasonTranslator.translateAction(
          'APPROVE_AS_SECONDARY_DESTINATION');
      expect(a.keepLabel, isNotEmpty);
      expect(a.excludeLabel, isNotEmpty);
      expect(a.reviewLabel, isNotEmpty);
    });

    test('returns safe fallback for unknown action codes', () {
      final a = ReviewReasonTranslator.translateAction('UNKNOWN_ACTION_2027');
      expect(a.keepLabel, isNotEmpty);
      expect(a.excludeLabel, isNotEmpty);
    });

    test('findUnknownCodes returns only unrecognised codes', () {
      final unknown = ReviewReasonTranslator.findUnknownCodes([
        'CONTRADICTORY_BUILDING_AMENITY',
        'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
        'NEW_UNKNOWN_CODE',
      ]);
      expect(unknown, contains('NEW_UNKNOWN_CODE'));
      expect(unknown, isNot(contains('CONTRADICTORY_BUILDING_AMENITY')));
    });
  });
}

// Helper: serialize a map to JSON string for test
String _toJson(Map<String, dynamic> m) => jsonEncode(m);
