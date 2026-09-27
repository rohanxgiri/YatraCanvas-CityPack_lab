import 'dart:io' show File;
import '../domain/lab_place.dart';
import 'city_pack_database.dart';
import 'local_image_resolver.dart';

class LocalPlaceRepository {
  final CityPackDatabase database;
  final LocalImageResolver imageResolver;

  LocalPlaceRepository({
    required this.database,
    required this.imageResolver,
  });

  String get cityId => database.cityId;

  Future<Map<String, int>> getCategories({bool onlyTravelRelevant = false}) =>
      database.getCategoriesWithCounts(onlyTravelRelevant: onlyTravelRelevant);

  Future<Map<String, int>> getTiers() => database.getTiersWithCounts();

  Future<Map<String, List<LabPlace>>> getDiscoverSections({
    List<String> interests = const [],
    int limitPerSection = 20,
  }) =>
      database.getDiscoverSections(
        interests: interests,
        limitPerSection: limitPerSection,
      );

  Future<List<LabPlace>> search({
    required String query,
    String? category,
    String? tier,
    bool onlyTravelRelevant = false,
    int limit = 50,
    int offset = 0,
  }) =>
      database.searchPlaces(
        query,
        category: category,
        tier: tier,
        onlyTravelRelevant: onlyTravelRelevant,
        limit: limit,
        offset: offset,
      );

  Future<List<LabPlace>> getByCategory({
    required String category,
    String sortBy = 'priority',
    bool onlyTravelRelevant = false,
    int limit = 50,
    int offset = 0,
  }) =>
      database.getPlacesByCategory(
        category,
        sortBy: sortBy,
        onlyTravelRelevant: onlyTravelRelevant,
        limit: limit,
        offset: offset,
      );

  Future<List<LabPlace>> getByTier({
    required String tier,
    int limit = 50,
    int offset = 0,
  }) =>
      database.getPlacesByTier(tier, limit: limit, offset: offset);

  Future<List<LabPlace>> getForMap({
    String? category,
    String? tier,
    int limit = 500,
  }) =>
      database.getAllPlacesForMap(category: category, tier: tier, limit: limit);

  Future<LabPlace?> getPlaceById(String id) => database.getPlaceById(id);

  Future<List<LabPlace>> getPlacesByIds(List<String> ids) =>
      database.getPlacesByIds(ids);

  Future<List<LabPlace>> getRandomPlaces({
    int count = 50,
    String? tier,
    String? category,
    int seed = 42,
  }) =>
      database.getRandomPlaces(
        count: count,
        tier: tier,
        category: category,
        seed: seed,
      );

  Future<Map<String, dynamic>> getQualityStats() => database.getQualityStats();

  Future<List<Map<String, dynamic>>> getCategoryCoverageMatrix() =>
      database.getCategoryCoverageMatrix();

  Future<List<LabPlace>> getPlacesForGap(
    String filterPreset, {
    int limit = 50,
    int offset = 0,
    String? category,
  }) =>
      database.getPlacesForGap(
        filterPreset,
        limit: limit,
        offset: offset,
        category: category,
      );

  File? resolveImage(String? relativeImagePath) =>
      imageResolver.resolveImage(relativeImagePath);

  String? resolveAssetPath(String? relativeImagePath) =>
      imageResolver.resolveAssetPath(relativeImagePath);
}
