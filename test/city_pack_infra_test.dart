import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_registry.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_database.dart';
import 'package:yatracanvas_citypack_lab/data/local_image_resolver.dart';
import 'package:yatracanvas_citypack_lab/data/local_place_repository.dart';
import 'package:yatracanvas_citypack_lab/domain/city_pack.dart';
import 'package:yatracanvas_citypack_lab/domain/lab_place.dart';
import 'package:yatracanvas_citypack_lab/domain/qa_issue.dart';
import 'package:yatracanvas_citypack_lab/domain/qa_session.dart';
import 'package:yatracanvas_citypack_lab/domain/trip_selection.dart';
import 'package:yatracanvas_citypack_lab/qa/qa_repository.dart';
import 'package:yatracanvas_citypack_lab/qa/qa_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempTestDir;
  late CityPackRegistry registry;

  setUpAll(() {
    tempTestDir = Directory.systemTemp.createTempSync('citypack_lab_test_');
    QaRepository.setOverrideDirectory(tempTestDir);
    registry = CityPackRegistry();
  });

  tearDownAll(() {
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('City Pack Discovery & Parsing', () {
    test('Discovers and parses synchronized production city packs', () async {
      final packs = await registry.loadAvailablePacks();
      expect(packs.isNotEmpty, isTrue);

      final manali = packs.firstWhere((p) => p.id == 'manali');
      expect(manali.name, 'Manali');
      expect(manali.state, 'Himachal Pradesh');
      expect(manali.placeCount, greaterThan(0));
      expect(manali.version, isNotEmpty);
      expect(manali.centerLat, greaterThan(0.0));
      expect(manali.centerLon, greaterThan(0.0));
      expect(manali.isValid, isTrue);
      expect(manali.integrityStatus, IntegrityStatus.pass);
    });

    test('Handles corrupt or missing pack gracefully', () {
      final invalidPack = CityPack.invalid(
        id: 'corrupt_city',
        reason: 'Manifest file missing',
      );
      expect(invalidPack.isValid, isFalse);
      expect(invalidPack.integrityStatus, IntegrityStatus.fail);
      expect(invalidPack.invalidReason, contains('Manifest file missing'));
    });
  });

  group('Database & Place Querying', () {
    late Database testDb;
    late CityPackDatabase packDb;
    late LocalPlaceRepository repo;

    setUpAll(() async {
      final manaliDbFile = File('assets/city_packs/manali/yatracanvas.db');
      expect(manaliDbFile.existsSync(), isTrue);

      // Open read-only
      testDb = await openReadOnlyDatabase(manaliDbFile.absolute.path);
      packDb = CityPackDatabase(testDb, 'manali');
      final imageResolver = LocalImageResolver(
        cityId: 'manali',
        imagesDirPath: 'assets/city_packs/manali/images',
      );
      repo = LocalPlaceRepository(
        database: packDb,
        imageResolver: imageResolver,
      );
    });

    tearDownAll(() async {
      await testDb.close();
    });

    test('Reads tiers and category counts accurately', () async {
      final tiers = await repo.getTiers();
      expect(tiers.containsKey('core_destination'), isTrue);
      expect(tiers['core_destination'], greaterThan(0));

      final categories = await repo.getCategories();
      expect(categories.isNotEmpty, isTrue);
      expect(categories.containsKey('heritage'), isTrue);
    });

    test('Tier filtering and discover sections', () async {
      final sections = await repo.getDiscoverSections(
        interests: ['heritage'],
        limitPerSection: 10,
      );
      expect(sections.containsKey('Top Destinations (Core)'), isTrue);
      final corePlaces = sections['Top Destinations (Core)']!;
      expect(corePlaces.isNotEmpty, isTrue);
      for (final p in corePlaces) {
        expect(p.tier, 'core_destination');
        expect(p.cityId, 'manali');
      }
    });

    test('Deterministic search and pagination', () async {
      final searchResults = await repo.search(query: 'Hadimba', limit: 5);
      expect(searchResults.isNotEmpty, isTrue);
      expect(
        searchResults.any((p) => p.name.toLowerCase().contains('hidimba') || p.name.toLowerCase().contains('hadimba')),
        isTrue,
      );

      // Pagination test
      final page1 = await repo.search(query: '', limit: 5, offset: 0);
      final page2 = await repo.search(query: '', limit: 5, offset: 5);
      expect(page1.length, 5);
      expect(page2.length, 5);
      expect(page1.first.id, isNot(equals(page2.first.id)));
    });

    test('Deterministic random review sampling', () async {
      final sample1 = await repo.getRandomPlaces(count: 10, seed: 101);
      final sample2 = await repo.getRandomPlaces(count: 10, seed: 101);
      expect(sample1.length, 10);
      expect(sample2.length, 10);
      for (int i = 0; i < 10; i++) {
        expect(sample1[i].id, sample2[i].id);
      }
    });

    test('Local image resolution and missing image placeholder condition', () async {
      // Find a place with image
      final placesWithImg = await repo.search(query: 'Manali', limit: 5);
      final imgPlace = placesWithImg.firstWhere((p) => p.hasLocalImage);
      final resolved = repo.resolveImage(imgPlace.primaryImagePath);
      expect(resolved, isNotNull);
      expect(resolved!.existsSync(), isTrue);

      // Verify missing image condition returns null (no fallback to fake image)
      final missingResolved = repo.resolveImage(null);
      expect(missingResolved, isNull);

      final nonexistent = repo.resolveImage('images/fake_place/primary.webp');
      expect(nonexistent, isNull);
    });

    test('Place detail mapping with tags, images, and sources', () async {
      final place = await repo.getPlaceById('yc_in_hp_manali_manali');
      expect(place, isNotNull);
      expect(place!.name, 'Manali');
      expect(place.tags.isNotEmpty, isTrue);
      expect(place.images.isNotEmpty, isTrue);
      expect(place.sources.isNotEmpty, isTrue);
    });
  });

  group('QA Session Persistence & Export', () {
    final qaRepo = QaRepository();
    final exportService = QaExportService();

    test('Persists issues and eliminates duplicate issue IDs', () async {
      const issueId = 'test_issue_manali_01';
      final issue1 = QaIssue(
        id: issueId,
        timestamp: DateTime.now().toIso8601String(),
        cityId: 'manali',
        packVersion: 'v3',
        placeId: 'yc_in_hp_manali_manali',
        placeName: 'Manali',
        tier: 'core_destination',
        category: 'heritage',
        latitude: 32.244,
        longitude: 77.188,
        issueType: QaIssueType.wrongCategory,
        note: 'First note',
      );

      await qaRepo.addIssue(issue1);

      // Re-add with updated note
      final issue2 = QaIssue(
        id: issueId,
        timestamp: DateTime.now().toIso8601String(),
        cityId: 'manali',
        packVersion: 'v3',
        placeId: 'yc_in_hp_manali_manali',
        placeName: 'Manali',
        tier: 'core_destination',
        category: 'heritage',
        latitude: 32.244,
        longitude: 77.188,
        issueType: QaIssueType.wrongCategory,
        note: 'Updated note',
      );
      await qaRepo.addIssue(issue2);

      final session = await qaRepo.loadSession('manali', 'v3');
      final matching = session.issues.where((i) => i.id == issueId).toList();
      expect(matching.length, 1);
      expect(matching.first.note, 'Updated note');

      // Delete issue test
      await qaRepo.deleteIssue('manali', issueId);
      final sessionAfterDelete = await qaRepo.loadSession('manali', 'v3');
      expect(sessionAfterDelete.issues.any((i) => i.id == issueId), isFalse);
    });

    test('TripSelection and geographic grouping', () {
      final trip = TripSelection(cityId: 'manali', tripDays: 3);
      trip.addPlace('p1');
      trip.addPlace('p2');
      trip.addPlace('p3');
      expect(trip.contains('p1'), isTrue);

      final dummyPlaces = [
        const LabPlace(
          id: 'p1',
          cityId: 'manali',
          name: 'P1',
          latitude: 32.2,
          longitude: 77.1,
          category: 'heritage',
          tier: 'core_destination',
          travelRelevanceScore: 1.0,
          prominenceScore: 1.0,
        ),
        const LabPlace(
          id: 'p2',
          cityId: 'manali',
          name: 'P2',
          latitude: 32.3,
          longitude: 77.2,
          category: 'heritage',
          tier: 'core_destination',
          travelRelevanceScore: 1.0,
          prominenceScore: 1.0,
        ),
        const LabPlace(
          id: 'p3',
          cityId: 'manali',
          name: 'P3',
          latitude: 32.4,
          longitude: 77.3,
          category: 'heritage',
          tier: 'core_destination',
          travelRelevanceScore: 1.0,
          prominenceScore: 1.0,
        ),
      ];

      trip.groupGeographically(dummyPlaces);
      expect(trip.getDayFor('p1'), isNotNull);
      expect(trip.getDayFor('p2'), isNotNull);
      expect(trip.getDayFor('p3'), isNotNull);
    });

    test('Exports machine-readable JSON and human-readable Markdown', () async {
      const pack = CityPack(
        id: 'manali',
        name: 'Manali',
        state: 'Himachal Pradesh',
        country: 'India',
        version: 'v3',
        placeCount: 1702,
        imageCount: 24,
        dbSizeMb: 2.13,
        integrityStatus: IntegrityStatus.pass,
        centerLat: 32.245,
        centerLon: 77.187,
        minLat: 32.16,
        minLon: 77.10,
        maxLat: 32.32,
        maxLon: 77.26,
      );

      final session = QaSession(
        cityId: 'manali',
        packVersion: 'v3',
        createdAt: DateTime.now().toIso8601String(),
        lastModified: DateTime.now().toIso8601String(),
        issues: [
          QaIssue(
            id: 'qa_export_01',
            timestamp: DateTime.now().toIso8601String(),
            cityId: 'manali',
            packVersion: 'v3',
            placeId: 'test_p1',
            placeName: 'Test Place',
            tier: 'core_destination',
            category: 'heritage',
            latitude: 32.2,
            longitude: 77.1,
            issueType: QaIssueType.wrongCategory,
            note: 'Export verification note',
          ),
        ],
      );

      final exportResult = await exportService.exportReport(
        pack: pack,
        session: session,
      );

      expect(exportResult.jsonContent, contains('manali'));
      expect(exportResult.jsonContent, contains('qa_export_01'));
      expect(exportResult.mdContent, contains('# YatraCanvas City Pack QA Report: Manali'));
      expect(File(exportResult.jsonFilePath).existsSync(), isTrue);
      expect(File(exportResult.mdFilePath).existsSync(), isTrue);
    });
  });
}
