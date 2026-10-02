import 'package:flutter_test/flutter_test.dart';
import 'package:yatracanvas_citypack_lab/domain/city_pack.dart';
import 'package:yatracanvas_citypack_lab/quality/models/manual_qa_summary.dart';
import 'package:yatracanvas_citypack_lab/quality/models/quality_dimension.dart';
import 'package:yatracanvas_citypack_lab/quality/models/release_gate_result.dart';
import 'package:yatracanvas_citypack_lab/quality/services/city_quality_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/data_gap_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/release_gate_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/travel_readiness_service.dart';

CityPack createMockPack({
  String id = 'jaipur',
  String name = 'Jaipur',
  String version = '1.4.0',
  int placeCount = 10000,
  int rawCandidates = 100000,
  int rejected = 90000,
  int quarantined = 0,
}) {
  return CityPack(
    id: id,
    name: name,
    state: 'Rajasthan',
    country: 'India',
    version: version,
    placeCount: placeCount,
    imageCount: 50,
    dbSizeMb: 14.0,
    centerLat: 26.9,
    centerLon: 75.8,
    minLat: 26.7,
    maxLat: 27.1,
    minLon: 75.6,
    maxLon: 76.0,
    integrityStatus: IntegrityStatus.pass,
    manifest: {
      'city': id,
      'pack_version': version,
      'generated_at': DateTime.now().toIso8601String(),
      'counts': {
        'places': placeCount,
        'raw_candidates': rawCandidates,
        'rejected': rejected,
        'quarantined': quarantined,
        'duplicate_merges': 500,
      },
    },
  );
}

void main() {
  group('City Lab Quality & Release Gate System Tests', () {
    const qualityService = CityQualityService();
    const travelService = TravelReadinessService();
    const releaseService = ReleaseGateService();
    const gapService = DataGapService();

    test('Case A — Excellent pack achieves READY status', () {
      final pack = createMockPack();
      final stats = {
        'total_places': 10000,
        'places_with_valid_category': 10000,
        'core_total': 80,
        'core_with_images': 75,
        'core_with_hours': 70,
        'core_with_wikidata': 75,
        'core_outside_bounds': 0,
        'places_outside_bounds': 0,
        'with_images': 8000,
        'with_opening_hours': 7500,
        'with_website': 8500,
        'with_phone': 8000,
        'shared_coords_places_count': 50,
        'multi_source_count': 6000,
        'category_counts': {
          'attraction': 200,
          'monument': 100,
          'museum': 40,
          'food': 2000,
          'hotel': 1500,
          'park': 80,
        },
      };

      // Sufficient manual QA with low defect rate
      const manualQa = ManualQaSummary(
        state: ManualQaState.sufficientSample,
        reviewedCount: 60,
        minimumRequired: 50,
        approvedCount: 57,
        issueCount: 3,
        uncertainCount: 0,
        score: 0.95,
      );

      final dq = qualityService.calculateScore(
        pack: pack,
        dbStats: stats,
        manualQa: manualQa,
      );
      final tr = travelService.calculateScore(pack: pack, dbStats: stats);
      final gate = releaseService.evaluate(
        pack: pack,
        dbStats: stats,
        dataQuality: dq,
        travelReadiness: tr,
        manualQa: manualQa,
      );

      expect(dq.overallScore, greaterThanOrEqualTo(80));
      expect(tr.overallScore, greaterThanOrEqualTo(75));
      expect(gate.criticalBlockers, isEmpty);
      expect(gate.status, equals(ReleaseStatus.ready));
      expect(gate.isReady, isTrue);
    });

    test('Case B — High score but bad Core coordinates is BLOCKED (Non-negotiable 0.2)', () {
      final pack = createMockPack();
      final stats = {
        'total_places': 10000,
        'places_with_valid_category': 10000,
        'core_total': 80,
        'core_with_images': 75,
        'core_with_hours': 70,
        'core_with_wikidata': 75,
        'core_outside_bounds': 4, // 4 Core POIs fail coordinates!
        'places_outside_bounds': 4,
        'with_images': 8000,
        'with_opening_hours': 7500,
        'with_website': 8500,
        'with_phone': 8000,
        'shared_coords_places_count': 0,
        'multi_source_count': 6000,
        'category_counts': {'attraction': 200, 'food': 2000},
      };

      const manualQa = ManualQaSummary(
        state: ManualQaState.sufficientSample,
        reviewedCount: 60,
        minimumRequired: 50,
        approvedCount: 58,
        issueCount: 2,
        uncertainCount: 0,
        score: 0.97,
      );

      final dq = qualityService.calculateScore(
        pack: pack,
        dbStats: stats,
        manualQa: manualQa,
      );
      final tr = travelService.calculateScore(pack: pack, dbStats: stats);
      final gate = releaseService.evaluate(
        pack: pack,
        dbStats: stats,
        dataQuality: dq,
        travelReadiness: tr,
        manualQa: manualQa,
      );

      // Even if overall numerical score is relatively high, critical failure MUST block release!
      expect(gate.status, equals(ReleaseStatus.blocked));
      expect(gate.isBlocked, isTrue);
      expect(
        gate.criticalBlockers.any((b) => b.contains('Core Destination')),
        isTrue,
      );
    });

    test(
      'Case C — Zero manual QA never produces 100% (Non-negotiable 0.1)',
      () {
        final pack = createMockPack();
        final stats = {
          'total_places': 10000,
          'places_with_valid_category': 10000,
          'core_total': 80,
          'core_with_images': 50,
          'core_with_hours': 40,
          'core_with_wikidata': 50,
          'core_outside_bounds': 0,
          'places_outside_bounds': 0,
          'with_images': 500,
          'with_opening_hours': 300,
          'with_website': 1000,
          'with_phone': 1000,
          'shared_coords_places_count': 10,
          'multi_source_count': 500,
          'category_counts': {'attraction': 50, 'food': 500},
        };

        // 0 reviews completed
        const manualQa = ManualQaSummary(
          state: ManualQaState.notStarted,
          reviewedCount: 0,
          minimumRequired: 50,
          approvedCount: 0,
          issueCount: 0,
          uncertainCount: 0,
          score: null,
        );

        expect(manualQa.score, isNull);
        expect(manualQa.displayStatus, equals('NOT_STARTED'));

        final dq = qualityService.calculateScore(
          pack: pack,
          dbStats: stats,
          manualQa: manualQa,
        );
        final manualDimension = dq.getDimension('manual_qa');

        expect(manualDimension, isNotNull);
        expect(manualDimension!.score, isNull);
        expect(manualDimension.status, equals(DimensionStatus.notMeasured));

        final tr = travelService.calculateScore(pack: pack, dbStats: stats);
        final gate = releaseService.evaluate(
          pack: pack,
          dbStats: stats,
          dataQuality: dq,
          travelReadiness: tr,
          manualQa: manualQa,
        );

        // Release must be blocked when manual QA has not started
        expect(gate.status, equals(ReleaseStatus.blocked));
        expect(
          gate.criticalBlockers.any((b) => b.contains('Manual QA not started')),
          isTrue,
        );
      },
    );

    test('Case D — Dirty raw pipeline does NOT penalize final City Pack quality (Non-negotiable 0.3)', () {
      // 100k raw candidates, 90k junk rejected, 10k excellent retained
      final packWithDirtyRaw = createMockPack(
        rawCandidates: 100000,
        rejected: 90000,
        quarantined: 5000,
        placeCount: 10000,
      );

      final stats = {
        'total_places': 10000,
        'places_with_valid_category': 10000,
        'core_total': 80,
        'core_with_images': 70,
        'core_with_hours': 60,
        'core_with_wikidata': 70,
        'core_outside_bounds': 0,
        'places_outside_bounds': 0,
        'with_images': 7000,
        'with_opening_hours': 6000,
        'with_website': 8000,
        'with_phone': 7500,
        'shared_coords_places_count': 10,
        'multi_source_count': 5000,
        'category_counts': {'attraction': 150, 'food': 2000},
      };

      const manualQa = ManualQaSummary(
        state: ManualQaState.sufficientSample,
        reviewedCount: 55,
        minimumRequired: 50,
        approvedCount: 52,
        issueCount: 3,
        uncertainCount: 0,
        score: 0.94,
      );

      final dq = qualityService.calculateScore(
        pack: packWithDirtyRaw,
        dbStats: stats,
        manualQa: manualQa,
      );
      packWithDirtyRaw.manifest['counts']['category_conflicts'] = 90000;
      final after = qualityService.calculateScore(
        pack: packWithDirtyRaw,
        dbStats: stats,
        manualQa: manualQa,
      );
      expect(after.overallScore, dq.overallScore);

      // The 90% rejection rate in raw candidates should NOT force the City Pack quality down to 10%
      expect(dq.overallScore, greaterThanOrEqualTo(75));
    });

    test('Case E — Clean but useless dataset gets high Data Quality but low Travel Readiness', () {
      final pack = createMockPack();
      // Perfect metadata, but 100% hotels and restaurants with ZERO attractions or core destinations!
      final stats = {
        'total_places': 5000,
        'places_with_valid_category': 5000,
        'core_total': 0, // No core destinations!
        'core_with_images': 0,
        'core_with_hours': 0,
        'core_with_wikidata': 0,
        'core_outside_bounds': 0,
        'places_outside_bounds': 0,
        'with_images': 4800,
        'with_opening_hours': 4500,
        'with_website': 4900,
        'with_phone': 4800,
        'shared_coords_places_count': 0,
        'multi_source_count': 4500,
        'category_counts': {'hotel': 3000, 'food_and_drink': 2000},
      };

      const manualQa = ManualQaSummary(
        state: ManualQaState.sufficientSample,
        reviewedCount: 50,
        minimumRequired: 50,
        approvedCount: 49,
        issueCount: 1,
        uncertainCount: 0,
        score: 0.98,
      );

      final dq = qualityService.calculateScore(
        pack: pack,
        dbStats: stats,
        manualQa: manualQa,
      );
      final tr = travelService.calculateScore(pack: pack, dbStats: stats);

      // Data Quality is high because metadata is clean
      expect(dq.overallScore, greaterThanOrEqualTo(70));

      // Travel readiness is severely penalized because zero tourist sights exist to build itineraries
      expect(tr.overallScore, lessThan(45));
      expect(tr.warnings.any((w) => w.contains('0 tourist sights')), isTrue);
    });

    test('Case F — Data Gap Analyzer accurately surfaces missing photo and hours buckets', () {
      final pack = createMockPack();
      final stats = {
        'total_places': 10060,
        'places_with_valid_category': 10060,
        'core_total': 80,
        'core_with_images': 47, // 33 missing photos
        'core_with_hours': 17, // 63 missing hours
        'core_outside_bounds': 0,
        'places_outside_bounds': 6,
        'with_images': 53,
        'with_opening_hours': 125,
        'shared_coords_places_count': 982,
        'multi_source_count': 754,
        'core_missing_image_ids': ['id1', 'id2'],
        'core_missing_hours_ids': ['id3', 'id4'],
        'outside_bounds_ids': ['id5'],
        'shared_coords_ids': ['id6', 'id7'],
      };

      final gaps = gapService.analyzeGaps(pack: pack, dbStats: stats);

      expect(
        gaps.any((g) => g.id == 'core_missing_images' && g.count == 33),
        isTrue,
      );
      expect(
        gaps.any((g) => g.id == 'core_missing_hours' && g.count == 63),
        isTrue,
      );
      expect(
        gaps.any((g) => g.id == 'places_outside_bounds' && g.count == 6),
        isTrue,
      );
      expect(
        gaps.any((g) => g.id == 'duplicate_coordinates' && g.count == 982),
        isTrue,
      );
    });
  });
}
