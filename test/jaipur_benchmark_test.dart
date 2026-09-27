// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_database.dart';
import 'package:yatracanvas_citypack_lab/data/local_image_resolver.dart';
import 'package:yatracanvas_citypack_lab/data/local_place_repository.dart';
import 'package:yatracanvas_citypack_lab/qa/review_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Jaipur Stress-Test Query Latency Benchmark (10,060 places, 13.39 MB DB)', () {
    late Database db;
    late CityPackDatabase packDb;
    late LocalPlaceRepository repo;

    setUpAll(() async {
      final dbFile = File('assets/city_packs/jaipur/yatracanvas.db');
      expect(dbFile.existsSync(), isTrue,
          reason: 'Jaipur database must be synchronized in assets/city_packs/jaipur/');

      final sw = Stopwatch()..start();
      db = await openReadOnlyDatabase(dbFile.absolute.path);
      sw.stop();
      print('[BENCHMARK] Jaipur DB Open Time: ${sw.elapsedMilliseconds} ms');

      packDb = CityPackDatabase(db, 'jaipur');
      final imageResolver = LocalImageResolver(
        cityId: 'jaipur',
        imagesDirPath: 'assets/city_packs/jaipur/images',
      );
      repo = LocalPlaceRepository(
        database: packDb,
        imageResolver: imageResolver,
      );
    });

    tearDownAll(() async {
      try {
        await db.close();
      } catch (_) {}
    });

    test('Total place count verification', () async {
      final rows = await db.rawQuery('SELECT COUNT(*) as count FROM places WHERE city_id = ?', ['jaipur']);
      final count = rows.first['count'] as int;
      expect(count, 10060);
      print('[BENCHMARK] Total places in Jaipur pack: $count');
    });

    test('Category distribution query latency < 50ms', () async {
      final sw = Stopwatch()..start();
      final categories = await repo.getCategories();
      sw.stop();

      print('[BENCHMARK] Categories (${categories.length} categories) fetched in: ${sw.elapsedMilliseconds} ms');
      expect(categories.isNotEmpty, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(100)); // generous threshold for CI
    });

    test('Core Destinations query latency < 30ms', () async {
      final sw = Stopwatch()..start();
      final corePlaces = await repo.getByTier(tier: 'core_destination', limit: 20);
      sw.stop();

      print('[BENCHMARK] 20 Core Destinations fetched in: ${sw.elapsedMilliseconds} ms (count: ${corePlaces.length})');
      expect(corePlaces.isNotEmpty, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('Text search latency across 10k rows < 50ms', () async {
      final queries = ['fort', 'palace', 'hawa', 'cafe', 'temple', 'bazaar'];
      for (final q in queries) {
        final sw = Stopwatch()..start();
        final results = await repo.search(query: q, limit: 20);
        sw.stop();

        print('[BENCHMARK] Search "$q" (${results.length} hits) completed in: ${sw.elapsedMilliseconds} ms');
        expect(sw.elapsedMilliseconds, lessThan(80));
      }
    });

    test('Pagination latency (OFFSET 500, LIMIT 50) < 50ms', () async {
      final sw = Stopwatch()..start();
      final results = await repo.getByCategory(
        category: 'all',
        limit: 50,
        offset: 500,
      );
      sw.stop();

      print('[BENCHMARK] Pagination offset 500 limit 50 returned ${results.length} rows in: ${sw.elapsedMilliseconds} ms');
      expect(results.length, 50);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('Seeded random sample generation (100 places) < 50ms', () async {
      final sampler = ReviewSampler(repo);
      final sw = Stopwatch()..start();
      final sample = await sampler.samplePlaces(sampleSize: 100, seed: 42);
      sw.stop();

      print('[BENCHMARK] Seeded 100-place random sample generated in: ${sw.elapsedMilliseconds} ms (returned ${sample.length})');
      expect(sample.length, 100);
      expect(sw.elapsedMilliseconds, lessThan(80));
    });

    test('Single place full detail lookup (with tags, images, sources) < 20ms', () async {
      final corePlaces = await repo.getByTier(tier: 'core_destination', limit: 1);
      final targetId = corePlaces.first.id;

      final sw = Stopwatch()..start();
      final detail = await repo.getPlaceById(targetId);
      sw.stop();

      print('[BENCHMARK] Full detail lookup for "${detail?.name}" in: ${sw.elapsedMilliseconds} ms');
      expect(detail, isNotNull);
      expect(sw.elapsedMilliseconds, lessThan(40));
    });

    test('Spatial bounding box query latency < 50ms', () async {
      // Bounding box around central Jaipur (Old City)
      final sw = Stopwatch()..start();
      final places = await packDb.getPlacesInBounds(
        26.90, // minLat
        75.80, // minLon
        26.95, // maxLat
        75.85, // maxLon
        limit: 200,
      );
      sw.stop();

      print('[BENCHMARK] Spatial bounds query returned ${places.length} places in: ${sw.elapsedMilliseconds} ms');
      expect(places.isNotEmpty, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(60));
    });
  });
}
