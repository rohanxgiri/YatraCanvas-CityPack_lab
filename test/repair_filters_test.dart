import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatracanvas_citypack_lab/app/app_state.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_repository.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_database.dart';
import 'package:yatracanvas_citypack_lab/data/local_place_repository.dart';
import 'package:yatracanvas_citypack_lab/data/local_image_resolver.dart';
import 'package:yatracanvas_citypack_lab/domain/lab_place.dart';

class FixtureRepository extends LocalPlaceRepository {
  FixtureRepository(CityPackDatabase database, this.places)
    : super(
        database: database,
        imageResolver: LocalImageResolver(cityId: 'fixture', imagesDirPath: ''),
      );
  final List<LabPlace> places;
  @override
  Future<List<LabPlace>> search({
    required String query,
    String? category,
    String? tier,
    bool onlyTravelRelevant = false,
    int limit = 50,
    int offset = 0,
  }) async => places;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'repair filters use effective fields and preserve verified baseline hours',
    () async {
      sqfliteFfiInit();
      final db = await createDatabaseFactoryFfi(noIsolate: true)
          .openDatabase(inMemoryDatabasePath);
      final directory = await Directory.systemTemp.createTemp('lab-filter-');
      CurationRepository.setOverrideDirectory(directory);
      final raw = LabPlace(
        id: 'fixture-place',
        cityId: 'fixture',
        name: 'Fixture',
        category: 'museum',
        tier: 'recommended',
        latitude: 26.9,
        longitude: 75.8,
        travelRelevanceScore: 0.7,
        prominenceScore: 0.7,
        openingHours: 'Mo 09:00-17:00',
      );
      final database = CityPackDatabase(
        db,
        'fixture',
        reviewMetadata: {
          raw.id: {'hours_state': 'VERIFIED'},
        },
      );
      final state = AppState()..repository = FixtureRepository(database, [raw]);
      try {
        await state.curationService.loadCityCuration('fixture');
        expect(
          await state.getCuratedPlaces(filter: 'unverified_hours'),
          isEmpty,
        );
        expect(
          await state.getCuratedPlaces(filter: 'missing_image'),
          hasLength(1),
        );
        await state.curationService.saveFieldOverride(
          place: raw,
          primaryImagePath: 'images/reviewed.webp',
          fieldName: 'primary_image_path',
          evidenceSource: 'Photo [License: UNVERIFIED_TEST_ONLY]',
        );
        expect(await state.getCuratedPlaces(filter: 'missing_image'), isEmpty);
        expect(
          await state.getCuratedPlaces(filter: 'test_only_image'),
          hasLength(1),
        );
        await state.curationService.saveFieldOverride(
          place: raw,
          openingHours: '',
          fieldName: 'opening_hours',
          evidenceSource: 'Unknown; check before visiting',
        );
        expect(
          await state.getCuratedPlaces(filter: 'unknown_hours'),
          hasLength(1),
        );
        state.curationService.sourcePackVersion = 'old-base';
        await state.curationService.saveFieldOverride(
          place: raw,
          name: 'Old correction',
          fieldName: 'name',
          evidenceSource: 'Reviewed on old base',
        );
        state.curationService.sourcePackVersion = 'new-base';
        await state.curationService.saveFieldOverride(
          place: raw,
          name: 'Old correction',
          description: 'New repair',
          fieldName: 'description',
          evidenceSource: 'Reviewed description',
        );
        expect(
          state.curationService.overrides[raw.id]!.fieldVersions['name'],
          'old-base',
        );
        expect(
          state.curationService.overrides[raw.id]!.fieldVersions['description'],
          'new-base',
        );
      } finally {
        state.dispose();
        CurationRepository.setOverrideDirectory(null);
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
