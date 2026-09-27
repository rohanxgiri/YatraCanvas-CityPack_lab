import 'dart:math';
import '../../domain/lab_place.dart';
import '../../data/city_pack_database.dart';

class QaSampleBucket {
  final String name;
  final String description;
  final List<LabPlace> places;

  const QaSampleBucket({
    required this.name,
    required this.description,
    required this.places,
  });
}

class StratifiedQaSample {
  final List<LabPlace> allPlaces;
  final Map<String, List<LabPlace>> bucketMap;
  final int totalCount;

  const StratifiedQaSample({
    required this.allPlaces,
    required this.bucketMap,
    required this.totalCount,
  });
}

class QaSamplingService {
  const QaSamplingService();

  Future<StratifiedQaSample> generateSample(
    CityPackDatabase db, {
    int targetTotal = 60,
    int coreQuota = 20,
    int anomalyQuota = 15,
    int categoryQuota = 15,
    int randomQuota = 10,
    int seed = 42,
  }) async {
    final Map<String, List<LabPlace>> bucketMap = {};
    final Set<String> seenPlaceIds = {};
    final List<LabPlace> unifiedList = [];

    void addPlace(String bucketName, LabPlace place) {
      if (!seenPlaceIds.contains(place.id)) {
        seenPlaceIds.add(place.id);
        unifiedList.add(place);
        bucketMap.putIfAbsent(bucketName, () => []).add(place);
      }
    }

    // 1. Core POIs Bucket
    final corePlaces = await db.getPlacesByTier('core_destination', limit: coreQuota * 2);
    final rng = Random(seed);
    final shuffledCore = List<LabPlace>.from(corePlaces)..shuffle(rng);
    for (final p in shuffledCore.take(coreQuota)) {
      addPlace('Core Destinations', p);
    }

    // 2. Potential Anomalies Bucket (outside bounds, missing images, duplicate coords)
    final stats = await db.getQualityStats();
    final List<String> anomalyIds = [];
    if (stats.containsKey('outside_bounds_ids')) {
      anomalyIds.addAll((stats['outside_bounds_ids'] as List<dynamic>).map((e) => e.toString()));
    }
    if (stats.containsKey('core_missing_image_ids')) {
      anomalyIds.addAll((stats['core_missing_image_ids'] as List<dynamic>).map((e) => e.toString()));
    }
    if (stats.containsKey('shared_coords_ids')) {
      anomalyIds.addAll((stats['shared_coords_ids'] as List<dynamic>).map((e) => e.toString()));
    }

    if (anomalyIds.isNotEmpty) {
      final anomalyPlaces = await db.getPlacesByIds(anomalyIds.take(anomalyQuota * 2).toList());
      final shuffledAnomalies = List<LabPlace>.from(anomalyPlaces)..shuffle(rng);
      for (final p in shuffledAnomalies.take(anomalyQuota)) {
        addPlace('Potential Anomalies & Gaps', p);
      }
    }

    // 3. Category Balanced Bucket
    final categories = await db.getCategoriesWithCounts();
    for (final entry in categories.entries) {
      if (bucketMap['Category Balanced'] != null && bucketMap['Category Balanced']!.length >= categoryQuota) {
        break;
      }
      final catPlaces = await db.getPlacesByCategory(entry.key, limit: 3);
      for (final p in catPlaces) {
        if (!seenPlaceIds.contains(p.id)) {
          addPlace('Category Balanced', p);
          break; // 1 per category for diversity
        }
      }
    }

    // 4. Random Sample Bucket
    final randomPlaces = await db.getRandomPlaces(count: randomQuota * 2, seed: seed);
    for (final p in randomPlaces) {
      if (bucketMap['Random Sample'] != null && bucketMap['Random Sample']!.length >= randomQuota) {
        break;
      }
      addPlace('Random Sample', p);
    }

    return StratifiedQaSample(
      allPlaces: unifiedList,
      bucketMap: bucketMap,
      totalCount: unifiedList.length,
    );
  }
}
