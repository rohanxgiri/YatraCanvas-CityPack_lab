import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:yatracanvas_citypack_lab/review/models/inbox_decision.dart';
import 'package:yatracanvas_citypack_lab/review/models/review_candidate.dart';
import 'package:yatracanvas_citypack_lab/review/repository/inbox_decision_repository.dart';
import 'package:yatracanvas_citypack_lab/review/services/review_manifest_loader.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_loader.dart';
import 'package:yatracanvas_citypack_lab/quality/services/qa_sampling_service.dart';
import 'package:yatracanvas_citypack_lab/quality/models/manual_qa_summary.dart';
import 'package:yatracanvas_citypack_lab/domain/qa_session.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/place_review.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'effective quality statistics export their curation summary as JSON',
    () {
      final stats = CurationService().computeCuratedStats({});
      final encoded = jsonDecode(jsonEncode(stats)) as Map<String, dynamic>;
      expect((encoded['curation_summary'] as Map)['total_reviews'], 0);
    },
  );
  test('manual QA accepts typed legacy and curator records without dynamic getter crashes', () {
    final summary = ManualQaSummary.fromCuration(
      reviews: [
        const RandomReviewRecord(
          placeId: 'legacy',
          placeName: 'Legacy',
          tier: 'support',
          category: 'hotel',
          result: 'looks_good',
          timestamp: 'now',
        ),
        const PlaceReview(
          id: 'review',
          placeId: 'curated',
          cityId: 'jaipur',
          placeName: 'Curated',
          tier: 'core_destination',
          category: 'heritage',
          verdict: 'missing_expected_information',
          reviewer: 'Curator',
          timestamp: 'now',
        ),
      ],
      issues: [],
    );
    expect(summary.reviewedCount, 2);
    expect(summary.approvedCount, 1);
    expect(summary.issueCount, 1);
    expect(summary.displayStatus, 'IN_PROGRESS (2/50)');
    expect(summary.isSufficient, isFalse);
    expect(
      ManualQaSummary.fromCuration(reviews: [], issues: []).displayStatus,
      'NOT_STARTED',
    );
  });
  final raw =
      (jsonDecode(
            File('assets/city_packs/jaipur/review_candidates.json')
                .readAsStringSync(),
          ) as List).first
          as Map<String, dynamic>;
  final candidate = ReviewCandidate.fromJson(raw);
  final repo = InboxDecisionRepository();
  InboxDecision decision(ReviewCandidate c) => InboxDecision(
    canonicalId: c.canonicalId,
    cityId: 'jaipur',
    packVersion: 'v3',
    verdict: InboxVerdict.approved,
    author: 'Audit fixture',
    decidedAt: '2026-10-01T00:00:00Z',
    snapshot: InboxDecisionSnapshot(
      travelRelevanceReason: c.travelRelevanceReason,
      travelRelevanceScore: c.travelRelevanceScore,
      confidence: c.confidence,
      suggestedAction: c.suggestedAction,
      missingFields: c.missingFields,
      semanticFields: InboxDecisionRepository.semanticFieldsOf(c),
    ),
  );

  test('real Jaipur identity collisions cannot share a curator decision', () {
    final result = ReviewManifestLoader().parseRawForTest(
      jsonEncode([raw, raw]),
      'jaipur',
    );
    expect(result.candidates, isEmpty);
    expect(result.warnings.single, contains('conflicting canonical IDs'));
  });

  test('unsupported review schema requires recovery', () {
    final result = ReviewManifestLoader().parseRawForTest(
      jsonEncode([
        {...raw, 'schema_version': '99.0'},
      ]),
      'jaipur',
    );
    expect(result.hasError, isTrue);
    expect(result.error, contains('Unsupported review schema'));
  });

  test('semantic changes reopen a real reviewed candidate', () {
    for (final change in <Map<String, dynamic>>[
      {'category': 'religious'},
      {'subcategory': 'temple'},
      {'tier': 'core_destination'},
      {'latitude': candidate.latitude + 0.001},
      {'wikidata_id': 'Q123'},
      {'commons_image': 'New photo'},
      {'confidence': candidate.confidence - 0.1},
      {
        'missing_fields': [...candidate.missingFields, 'license'],
      },
      {
        'osm_tags': {...candidate.osmTags, 'building': 'church'},
      },
      {
        'external_ids': {
          'openstreetmap_ids': ['node/changed'],
        },
      },
    ]) {
      final fresh = ReviewCandidate.fromJson({...raw, ...change});
      final changed = repo.detectChanges(
        existing: decision(candidate),
        fresh: fresh,
      );
      expect(changed, isNotNull, reason: change.toString());
      expect(changed!.changedSinceReview, isTrue);
      expect(changed.isResolved, isFalse);
    }
  });

  test(
    'timestamps, tag ordering and small coordinate noise do not reopen review',
    () {
      final fresh = ReviewCandidate.fromJson({
        ...raw,
        'generated_at': '2099-01-01',
        'latitude': candidate.latitude + 0.00001,
        'osm_tags': Map.fromEntries(
          candidate.osmTags.entries.toList().reversed,
        ),
        'missing_fields': candidate.missingFields.reversed.toList(),
      });
      expect(
        repo.detectChanges(existing: decision(candidate), fresh: fresh),
        isNull,
      );
    },
  );

  test('real candidate decision survives repository reopening', () async {
    final dir = await Directory.systemTemp.createTemp('citylab-audit-');
    InboxDecisionRepository.setOverrideDirectory(dir);
    try {
      await repo.saveDecision(decision(candidate));
      final saved = await InboxDecisionRepository().loadDecisions('jaipur');
      expect(
        saved[candidate.canonicalId]!.toJson(),
        decision(candidate).toJson(),
      );
      await repo.saveDecision(decision(candidate));
      expect(
        await dir
            .list(recursive: true)
            .where((f) => f.path.endsWith('.json'))
            .length,
        1,
      );
    } finally {
      InboxDecisionRepository.setOverrideDirectory(null);
      await dir.delete(recursive: true);
    }
  });

  test(
    'all synchronized cities have a reproducible diverse full QA sample',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'citylab-sample-audit-',
      );
      CityPackLoader.setOverrideDirectory(dir);
      try {
        for (final city in ['jaipur', 'udaipur', 'varanasi']) {
          final loaded = await CityPackLoader().openCityPack(city);
          try {
            const sampler = QaSamplingService();
            final sample = await sampler.generateSample(loaded.packDatabase);
            final again = await sampler.generateSample(loaded.packDatabase);
            expect(sample.totalCount, 60, reason: city);
            expect(sample.allPlaces.map((p) => p.id).toSet().length, 60);
            expect(
              sample.allPlaces.map((p) => p.id),
              again.allPlaces.map((p) => p.id),
            );
            expect(
              sample.allPlaces.map((p) => p.tier).toSet(),
              containsAll([
                'core_destination',
                'recommended',
                'discovery',
                'support',
              ]),
            );
            expect(
              sample.allPlaces.map((p) => p.category).toSet().length,
              greaterThanOrEqualTo(7),
            );
            final tiers = <String, int>{};
            final categories = <String, int>{};
            for (final p in sample.allPlaces) {
              tiers.update(p.tier, (n) => n + 1, ifAbsent: () => 1);
              categories.update(p.category, (n) => n + 1, ifAbsent: () => 1);
            }
            debugPrint('$city QA sample tiers=$tiers categories=$categories');
          } finally {
            await loaded.database.close();
          }
        }
      } finally {
        CityPackLoader.setOverrideDirectory(null);
        await dir.delete(recursive: true);
      }
    },
  );
}
