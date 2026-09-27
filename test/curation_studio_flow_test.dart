import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_repository.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_service.dart';
import 'package:yatracanvas_citypack_lab/domain/city_pack.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/place_addition.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/place_override.dart';
import 'package:yatracanvas_citypack_lab/domain/lab_place.dart';
import 'package:yatracanvas_citypack_lab/quality/models/data_quality_score.dart';
import 'package:yatracanvas_citypack_lab/quality/models/manual_qa_summary.dart';
import 'package:yatracanvas_citypack_lab/quality/models/travel_readiness_score.dart';
import 'package:yatracanvas_citypack_lab/quality/services/release_gate_service.dart';

void main() {
  late Directory tempDir;
  late CurationRepository repository;
  late CurationService service;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('curation_studio_flow_');
    CurationRepository.setOverrideDirectory(tempDir);
    repository = CurationRepository();
    service = CurationService(repository: repository, currentContributor: 'Rohan');
    await service.loadCityCuration('jaipur');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  const dummyCityPack = CityPack(
    id: 'jaipur',
    name: 'Jaipur',
    state: 'Rajasthan',
    country: 'India',
    version: '1.4.0',
    placeCount: 10060,
    imageCount: 8500,
    dbSizeMb: 12.5,
    integrityStatus: IntegrityStatus.pass,
    centerLat: 26.9124,
    centerLon: 75.7873,
    minLat: 26.80,
    minLon: 75.65,
    maxLat: 27.05,
    maxLon: 75.95,
    manifest: {
      'city_id': 'jaipur',
      'pack_version': '1.4.0',
      'counts': {'places': 10060},
    },
  );

  const highDataQuality = DataQualityScore(
    overallScore: 92,
    dimensions: {},
    summary: 'High Data Quality',
  );

  const highTravelReadiness = TravelReadinessScore(
    overallScore: 88,
    dimensions: {},
    warnings: [],
    summary: 'High Travel Readiness',
  );

  group('Full Curation Studio Workflow Simulation', () {
    test('Detect, Fix, Persist, Recalculate, and Revert workflow', () async {
      // 1. Raw Places with various data issues:
      // - p1: missing image, missing opening hours
      // - p2: wrong category ('food' instead of 'heritage')
      // - p3: coordinate outside bounds
      // - p4: duplicate or inappropriate POI
      final rawPlaces = [
        const LabPlace(
          id: 'poi_01',
          cityId: 'jaipur',
          name: 'Hawa Mahal',
          latitude: 26.9239,
          longitude: 75.8267,
          category: 'heritage',
          tier: 'core_destination',
          travelRelevanceScore: 0.95,
          prominenceScore: 0.90,
          openingHours: null, // Issue: Missing Hours
          primaryImagePath: null, // Issue: Missing Image
        ),
        const LabPlace(
          id: 'poi_02',
          cityId: 'jaipur',
          name: 'Albert Hall Museum',
          latitude: 26.9116,
          longitude: 75.8195,
          category: 'food', // Issue: Wrong Category
          tier: 'core_destination',
          travelRelevanceScore: 0.88,
          prominenceScore: 0.82,
          openingHours: '09:00-17:00',
          primaryImagePath: 'images/albert/1.webp',
        ),
        const LabPlace(
          id: 'poi_03',
          cityId: 'jaipur',
          name: 'Out of Bounds Sight',
          latitude: 30.0000, // Issue: Coordinates outside Jaipur (26.8-27.05)
          longitude: 75.8000,
          category: 'heritage',
          tier: 'core_destination',
          travelRelevanceScore: 0.50,
          prominenceScore: 0.40,
        ),
        const LabPlace(
          id: 'poi_04',
          cityId: 'jaipur',
          name: 'Private Corporate Mess',
          latitude: 26.9000,
          longitude: 75.8000,
          category: 'food',
          tier: 'neighborhood_gem',
          travelRelevanceScore: 0.10,
          prominenceScore: 0.10,
        ),
      ];

      // Initial stats
      final initialStats = {
        'total_places': 4,
        'core_total': 3,
        'with_images': 1,
        'with_opening_hours': 1,
        'places_outside_bounds': 1,
        'core_outside_bounds': 1,
        'category_counts': {'heritage': 2, 'food': 2},
      };

      // 2. Fix Missing Image and Opening Hours on poi_01
      await service.saveFieldOverride(
        place: rawPlaces[0],
        fieldName: 'opening_hours',
        openingHours: '09:00-17:00',
        evidenceSource: 'Official Tourism Board',
      );

      await service.saveFieldOverride(
        place: rawPlaces[0],
        fieldName: 'primary_image_path',
        primaryImagePath: 'images/hawa_mahal/curated.webp',
        evidenceSource: 'Wikimedia Commons',
      );

      // 3. Fix Wrong Category on poi_02
      await service.saveFieldOverride(
        place: rawPlaces[1],
        fieldName: 'category',
        category: 'museum',
        evidenceSource: 'Manual Curation',
      );

      // 4. Correct Coordinates on poi_03 to bring inside bounds
      await service.saveFieldOverride(
        place: rawPlaces[2],
        fieldName: 'coordinates',
        latitude: 26.9200,
        longitude: 75.8100,
        evidenceSource: 'Verified Pin Relocation',
        previousValue: true,
      );

      // 5. Exclude inappropriate place poi_04
      await service.excludePlace(
        cityId: 'jaipur',
        placeId: 'poi_04',
        placeName: 'Private Corporate Mess',
        reason: 'Restricted corporate cafeteria not open to public',
      );

      // 6. Add a missing Core POI manually
      const addedPlace = PlaceAddition(
        id: 'manual_amber_fort_stepwell',
        cityId: 'jaipur',
        name: 'Panna Meena Ka Kund',
        category: 'heritage',
        tier: 'core_destination',
        latitude: 26.9855,
        longitude: 75.8507,
        description: 'Historic 16th-century stepwell near Amer Fort',
        openingHours: '06:00-18:00',
        primaryImagePath: 'images/panna_meena.webp',
        author: 'Rohan',
        createdAt: '2026-09-27T10:00:00Z',
        evidenceSource: 'Archaeological Survey of India',
      );
      await service.addPlace(addedPlace);

      // 7. Recompute curated stats dynamically
      final updatedStats = service.computeCuratedStats(initialStats);

      // Assertions on dynamically recalculated stats:
      // Total places: 4 raw - 1 excluded + 1 added = 4
      expect(updatedStats['total_places'], equals(4));
      // Core places: 3 raw + 1 added = 4
      expect(updatedStats['core_total'], equals(4));
      // With images: raw 1 + override poi_01 (1) + addition (1) = 3
      expect(updatedStats['with_images'], equals(3));
      // With hours: raw 1 + override poi_01 (1) + addition (1) = 3
      expect(updatedStats['with_opening_hours'], equals(3));
      // Core places outside bounds: poi_03 was moved inside bounds!
      expect(updatedStats['core_outside_bounds'], equals(0));
      expect(updatedStats['places_outside_bounds'], equals(0));

      // 8. Test Resolution:
      // Excluded poi_04 must be marked excluded
      expect(service.isExcluded('poi_04'), isTrue);
      // Added place must be resolvable
      final resolvedAddition = service.resolveAddition('manual_amber_fort_stepwell');
      expect(resolvedAddition, isNotNull);
      expect(resolvedAddition!.name, equals('Panna Meena Ka Kund'));
      expect(resolvedAddition.isCore, isTrue);

      // Overridden poi_01 has curated values
      final curatedHawa = service.resolve(rawPlaces[0]);
      expect(curatedHawa.openingHours, equals('09:00-17:00'));
      expect(curatedHawa.primaryImagePath, equals('images/hawa_mahal/curated.webp'));
      expect(curatedHawa.isManuallyEdited, isTrue);

      // 9. Test Revert: Reverting override restores raw place
      await service.revertOverride('jaipur', 'poi_01');
      final revertedHawa = service.resolve(rawPlaces[0]);
      expect(revertedHawa.primaryImagePath, isNull); // Back to raw null
      expect(revertedHawa.openingHours, isNull); // Back to raw null
    });

    test('Deterministic Serialization produces Git-friendly JSON', () async {
      const override = PlaceOverride(
        placeId: 'osm_12345',
        cityId: 'jaipur',
        packVersion: 'v3',
        name: 'City Palace',
        openingHours: '09:30-17:30',
        fieldSources: {'opening_hours': 'Official Tickets Counter'},
        author: 'Rohan',
        updatedAt: '2026-09-27T12:00:00Z',
      );

      await repository.saveOverride(override);

      final file = File('${tempDir.path}/jaipur/curation/overrides/osm_12345.json');
      expect(file.existsSync(), isTrue);

      final content1 = file.readAsStringSync();
      final parsed1 = json.decode(content1) as Map<String, dynamic>;

      // Re-saving identical content must be 100% deterministic (no noisy line diffs)
      await repository.saveOverride(override);
      final content2 = file.readAsStringSync();
      expect(content1, equals(content2));

      // Indented formatted JSON
      expect(content1.contains('\n'), isTrue);
      expect(parsed1['place_id'], equals('osm_12345'));
      expect(parsed1['author'], equals('Rohan'));
    });

    test('Manual QA sample tracking enforces gates: 0 reviews != 100%', () {
      const releaseService = ReleaseGateService();

      // State A: 0 reviews
      const emptyQa = ManualQaSummary(
        state: ManualQaState.notStarted,
        reviewedCount: 0,
        minimumRequired: 50,
        approvedCount: 0,
        issueCount: 0,
        uncertainCount: 0,
      );

      final resultEmpty = releaseService.evaluate(
        pack: dummyCityPack,
        dbStats: {
          'core_outside_bounds': 0,
          'places_outside_bounds': 0,
          'category_counts': {'heritage': 25, 'food': 25},
        },
        dataQuality: highDataQuality,
        travelReadiness: highTravelReadiness,
        manualQa: emptyQa,
      );

      // Gate 3 (Manual QA) must FAIL because sample is 0 / 50
      expect(resultEmpty.checks['manual_qa_sufficient'], isFalse);
      expect(resultEmpty.isBlocked, isTrue);

      // State B: 50 reviews completed, all accepted
      const completedQa = ManualQaSummary(
        state: ManualQaState.sufficientSample,
        reviewedCount: 50,
        minimumRequired: 50,
        approvedCount: 50,
        issueCount: 0,
        uncertainCount: 0,
        score: 1.0,
      );

      final resultPassed = releaseService.evaluate(
        pack: dummyCityPack,
        dbStats: {
          'core_outside_bounds': 0,
          'places_outside_bounds': 0,
          'category_counts': {'heritage': 25, 'food': 25},
        },
        dataQuality: highDataQuality,
        travelReadiness: highTravelReadiness,
        manualQa: completedQa,
      );

      expect(resultPassed.checks['manual_qa_sufficient'], isTrue);
      expect(resultPassed.isReady, isTrue);
    });

    test('Critical Gates Override Averages: High DQ + TR blocked by Core POI Out of Bounds', () {
      const releaseService = ReleaseGateService();
      const completedQa = ManualQaSummary(
        state: ManualQaState.sufficientSample,
        reviewedCount: 50,
        minimumRequired: 50,
        approvedCount: 50,
        issueCount: 0,
        uncertainCount: 0,
        score: 1.0,
      );

      // Even with 92 DQ and 88 TR, 1 Core POI outside bounds BLOCKS release!
      final result = releaseService.evaluate(
        pack: dummyCityPack,
        dbStats: {
          'core_outside_bounds': 1, // 1 Core place outside bounds!
          'places_outside_bounds': 1,
          'category_counts': {'heritage': 25, 'food': 25},
        },
        dataQuality: highDataQuality,
        travelReadiness: highTravelReadiness,
        manualQa: completedQa,
      );

      expect(result.checks['core_geo_integrity'], isFalse);
      expect(result.isBlocked, isTrue);
      expect(result.criticalBlockers.any((b) => b.contains('Core Destination(s) failed geographic')), isTrue);
    });
  });
}
