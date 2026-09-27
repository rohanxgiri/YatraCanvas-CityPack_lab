import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_repository.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_service.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/curated_place.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/curation_issue.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/place_addition.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/place_exclusion.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/place_override.dart';
import 'package:yatracanvas_citypack_lab/domain/lab_place.dart';

void main() {
  late Directory tempDir;
  late CurationRepository repository;
  late CurationService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('curation_test_');
    CurationRepository.setOverrideDirectory(tempDir);
    repository = CurationRepository();
    service = CurationService(repository: repository, currentContributor: 'Alice');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  final dummyRawPlace = LabPlace(
    id: 'test_place_01',
    cityId: 'jaipur',
    name: 'Albert Hall',
    latitude: 26.9124,
    longitude: 75.7873,
    category: 'museum',
    tier: 'core_destination',
    travelRelevanceScore: 0.90,
    prominenceScore: 0.85,
    openingHours: '09:00-17:00',
    primaryImagePath: null,
  );

  test('CuratedPlace resolution respects precedence: Human Override > Raw Place', () {
    final override = PlaceOverride(
      placeId: 'test_place_01',
      cityId: 'jaipur',
      packVersion: 'v3',
      name: 'Albert Hall Museum (Curated)',
      openingHours: '09:30-18:00',
      primaryImagePath: 'images/albert_hall/primary.webp',
      fieldSources: {
        'opening_hours': 'Official Government Website',
        'image': 'Uploaded from Commons',
      },
      author: 'Alice',
      updatedAt: '2026-09-27T10:00:00Z',
    );

    final curated = CuratedPlace(
      rawPlace: dummyRawPlace,
      override: override,
    );

    expect(curated.name, equals('Albert Hall Museum (Curated)'));
    expect(curated.openingHours, equals('09:30-18:00'));
    expect(curated.hasImage, isTrue);
    expect(curated.primaryImagePath, equals('images/albert_hall/primary.webp'));
    expect(curated.isManuallyEdited, isTrue);
    expect(curated.isExcluded, isFalse);

    final prov = curated.getProvenance('opening_hours');
    expect(prov.isManuallyVerified, isTrue);
    expect(prov.sourceLabel, contains('Official Government Website'));
  });

  test('CuratedPlace resolution respects additions and exclusions', () {
    final addition = PlaceAddition(
      id: 'manual_001',
      cityId: 'jaipur',
      name: 'Hidden Stepwell Cafe',
      category: 'cafe',
      tier: 'recommended',
      latitude: 26.9200,
      longitude: 75.8000,
      openingHours: '10:00-22:00',
      author: 'Bob',
      createdAt: '2026-09-27T10:00:00Z',
      evidenceSource: 'Personal visit on Sep 2026',
    );

    final curatedAdd = CuratedPlace(addition: addition);
    expect(curatedAdd.name, equals('Hidden Stepwell Cafe'));
    expect(curatedAdd.isManuallyAdded, isTrue);
    expect(curatedAdd.isExcluded, isFalse);

    final exclusion = PlaceExclusion(
      placeId: 'manual_001',
      cityId: 'jaipur',
      placeName: 'Hidden Stepwell Cafe',
      reason: 'closed_permanently',
      excludedBy: 'Alice',
      timestamp: '2026-09-27T11:00:00Z',
    );

    final curatedExcluded = CuratedPlace(
      addition: addition,
      exclusion: exclusion,
    );
    expect(curatedExcluded.isExcluded, isTrue);
  });

  test('CurationRepository persists and reloads overrides, additions, exclusions', () async {
    final override = PlaceOverride(
      placeId: 'p_100',
      cityId: 'jaipur',
      packVersion: 'v3',
      name: 'Hawa Mahal Corrected',
      openingHours: '09:00-17:00',
      author: 'Alice',
      updatedAt: '2026-09-27T12:00:00Z',
    );
    await repository.saveOverride(override);

    final addition = PlaceAddition(
      id: 'p_add_200',
      cityId: 'jaipur',
      name: 'New Art Gallery',
      category: 'arts_culture',
      latitude: 26.90,
      longitude: 75.80,
      author: 'Alice',
      createdAt: '2026-09-27T12:00:00Z',
      evidenceSource: 'Official museum registry',
    );
    await repository.saveAddition(addition);

    final exclusion = PlaceExclusion(
      placeId: 'p_bad_300',
      cityId: 'jaipur',
      placeName: 'Closed Bar',
      reason: 'closed_permanently',
      excludedBy: 'Alice',
      timestamp: '2026-09-27T12:00:00Z',
    );
    await repository.saveExclusion(exclusion);

    // Reload
    final reloadedOverrides = await repository.loadOverrides('jaipur');
    expect(reloadedOverrides.length, equals(1));
    expect(reloadedOverrides.first.name, equals('Hawa Mahal Corrected'));

    final reloadedAdditions = await repository.loadAdditions('jaipur');
    expect(reloadedAdditions.length, equals(1));
    expect(reloadedAdditions.first.name, equals('New Art Gallery'));

    final reloadedExclusions = await repository.loadExclusions('jaipur');
    expect(reloadedExclusions.length, equals(1));
    expect(reloadedExclusions.first.reason, equals('closed_permanently'));
  });

  test('CurationService computeCuratedStats updates statistics dynamically', () async {
    await service.loadCityCuration('jaipur');

    // Baseline stats from DB
    final rawStats = {
      'total_places': 100,
      'core_total': 10,
      'with_images': 20,
      'with_opening_hours': 15,
      'core_with_images': 5,
      'core_with_hours': 4,
      'core_outside_bounds': 1,
      'places_outside_bounds': 2,
      'category_counts': {'museum': 10, 'cafe': 10},
      'tier_counts': {'core_destination': 10, 'recommended': 90},
    };

    // 1. Add an override for hours and photos
    await service.saveFieldOverride(
      place: dummyRawPlace,
      openingHours: '09:00-18:00',
      primaryImagePath: 'images/albert/primary.webp',
      fieldName: 'opening_hours',
      evidenceSource: 'Verified website',
      previousValue: '',
    );

    // 2. Add a new Core place
    await service.addPlace(PlaceAddition(
      id: 'add_core_1',
      cityId: 'jaipur',
      name: 'Flagship Palace',
      category: 'heritage',
      tier: 'core_destination',
      latitude: 26.91,
      longitude: 75.78,
      primaryImagePath: 'images/palace/primary.webp',
      openingHours: '09:00-17:00',
      author: 'Alice',
      createdAt: '2026-09-27T12:00:00Z',
      evidenceSource: 'Official source',
    ));

    // 3. Exclude an irrelevant place
    await service.excludePlace(
      cityId: 'jaipur',
      placeId: 'bad_p1',
      placeName: 'Govt Canteen',
      reason: 'institutional_canteen',
    );

    final curatedStats = service.computeCuratedStats(rawStats);

    // Total places: 100 + 1 addition - 1 exclusion = 100
    expect(curatedStats['total_places'], equals(100));
    // Core total: 10 + 1 addition = 11
    expect(curatedStats['core_total'], equals(11));
    // Core with images: 5 + 1 (override) + 1 (addition) = 7
    expect(curatedStats['core_with_images'], equals(7));
    // Core with hours: 4 + 1 (override) + 1 (addition) = 6
    expect(curatedStats['core_with_hours'], equals(6));

    // PR Summary
    final prSummary = service.generatePrSummary('Jaipur');
    expect(prSummary, contains('JAIPUR CURATION SUMMARY'));
    expect(prSummary, contains('Total Curation Changes'));
  });

  test('CurationIssue lifecycle transitions: OPEN -> FIXED -> VERIFIED', () async {
    await service.loadCityCuration('jaipur');

    await service.logIssue(
      cityId: 'jaipur',
      placeId: 'place_123',
      placeName: 'Old Fort',
      issueType: 'wrong_hours',
      note: 'Hours listed are outdated',
    );

    expect(service.issues.length, equals(1));
    final issue = service.issues.values.first;
    expect(issue.status, equals(CurationIssueStatus.open));

    // Update status to fixed
    await service.updateIssueStatus(issue.id, CurationIssueStatus.fixed, resolutionNote: 'Updated to 09:00-17:00');
    expect(service.issues[issue.id]!.status, equals(CurationIssueStatus.fixed));
    expect(service.issues[issue.id]!.isResolved, isTrue);

    // Update to verified
    await service.updateIssueStatus(issue.id, CurationIssueStatus.verified);
    expect(service.issues[issue.id]!.status, equals(CurationIssueStatus.verified));
  });
}
