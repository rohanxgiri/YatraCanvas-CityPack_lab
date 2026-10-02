import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../domain/lab_place.dart';

class CityPackDatabase {
  final Database db;
  final String cityId;

  CityPackDatabase(this.db, this.cityId);

  Future<Map<String, int>> getCategoriesWithCounts({
    bool onlyTravelRelevant = false,
  }) async {
    String query = '''
      SELECT category, COUNT(*) as count 
      FROM places 
      WHERE city_id = ?
    ''';
    final List<dynamic> args = [cityId];

    if (onlyTravelRelevant) {
      query += ' AND travel_relevance_score > 0.0';
    }

    query += ' GROUP BY category ORDER BY count DESC';

    final rows = await db.rawQuery(query, args);
    final Map<String, int> result = {};
    for (final r in rows) {
      final cat = r['category'] as String? ?? 'other';
      result[cat] = (r['count'] as int?) ?? 0;
    }
    return result;
  }

  Future<Map<String, int>> getTiersWithCounts() async {
    const query = '''
      SELECT tier, COUNT(*) as count 
      FROM places 
      WHERE city_id = ?
      GROUP BY tier 
      ORDER BY count DESC
    ''';
    final rows = await db.rawQuery(query, [cityId]);
    final Map<String, int> result = {};
    for (final r in rows) {
      final tier = r['tier'] as String? ?? 'unknown';
      result[tier] = (r['count'] as int?) ?? 0;
    }
    return result;
  }

  Future<Map<String, List<LabPlace>>> getDiscoverSections({
    List<String> interests = const [],
    int limitPerSection = 20,
  }) async {
    final Map<String, List<LabPlace>> sections = {};

    // 1. Top / Core destinations
    final coreRows = await db.rawQuery(
      '''
      SELECT * FROM places 
      WHERE city_id = ? AND tier = 'core_destination'
      ORDER BY tourism_priority DESC, travel_relevance_score DESC
      LIMIT ?
    ''',
      [cityId, limitPerSection],
    );
    sections['Top Destinations (Core)'] = coreRows
        .map((r) => LabPlace.fromMap(r))
        .toList();

    // 2. Recommended
    final recRows = await db.rawQuery(
      '''
      SELECT * FROM places 
      WHERE city_id = ? AND tier = 'recommended'
      ORDER BY travel_relevance_score DESC, tourism_priority DESC
      LIMIT ?
    ''',
      [cityId, limitPerSection],
    );
    sections['Recommended'] = recRows.map((r) => LabPlace.fromMap(r)).toList();

    // 3. Based on selected interests
    if (interests.isNotEmpty) {
      final placeholders = List.filled(interests.length, '?').join(',');
      final interestRows = await db.rawQuery(
        '''
        SELECT * FROM places 
        WHERE city_id = ? AND category IN ($placeholders)
        ORDER BY tourism_priority DESC, travel_relevance_score DESC
        LIMIT ?
      ''',
        [cityId, ...interests, limitPerSection],
      );
      sections['Based on Interests (${interests.join(', ')})'] = interestRows
          .map((r) => LabPlace.fromMap(r))
          .toList();
    }

    // 4. Discover / Lesser-known
    final discRows = await db.rawQuery(
      '''
      SELECT * FROM places 
      WHERE city_id = ? AND tier = 'discovery'
      ORDER BY travel_relevance_score DESC, tourism_priority DESC
      LIMIT ?
    ''',
      [cityId, limitPerSection],
    );
    sections['Discover / Lesser-Known'] = discRows
        .map((r) => LabPlace.fromMap(r))
        .toList();

    // 5. Food & Cafes
    final foodRows = await db.rawQuery(
      '''
      SELECT * FROM places 
      WHERE city_id = ? AND (category IN ('food', 'cafe') OR subcategory IN ('cafe', 'restaurant', 'food'))
      ORDER BY travel_relevance_score DESC, tourism_priority DESC
      LIMIT ?
    ''',
      [cityId, limitPerSection],
    );
    if (foodRows.isNotEmpty) {
      sections['Food & Cafes'] = foodRows
          .map((r) => LabPlace.fromMap(r))
          .toList();
    }

    return sections;
  }

  Future<List<LabPlace>> searchPlaces(
    String query, {
    String? category,
    String? tier,
    bool onlyTravelRelevant = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final cleanQuery = query.trim();
    final List<dynamic> args = [cityId];

    final List<String> conditions = ['city_id = ?'];

    if (cleanQuery.isNotEmpty) {
      final pattern = '%$cleanQuery%';
      conditions.add('''
        (name LIKE ? 
         OR name_hi LIKE ? 
         OR category LIKE ? 
         OR subcategory LIKE ? 
         OR primary_entity_type LIKE ? 
         OR address LIKE ?
         OR id IN (SELECT place_id FROM place_tags WHERE tag LIKE ?))
      ''');
      args.addAll([
        pattern,
        pattern,
        pattern,
        pattern,
        pattern,
        pattern,
        pattern,
      ]);
    }

    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'all') {
      conditions.add('category = ?');
      args.add(category);
    }

    if (tier != null && tier.isNotEmpty && tier.toLowerCase() != 'all') {
      conditions.add('tier = ?');
      args.add(tier);
    }

    if (onlyTravelRelevant) {
      conditions.add('travel_relevance_score > 0.0');
    }

    final whereClause = conditions.join(' AND ');
    final sql =
        '''
      SELECT * FROM places 
      WHERE $whereClause
      ORDER BY tourism_priority DESC, travel_relevance_score DESC, name ASC
      LIMIT ? OFFSET ?
    ''';
    args.add(limit);
    args.add(offset);

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => LabPlace.fromMap(r)).toList();
  }

  Future<List<LabPlace>> getPlacesByCategory(
    String category, {
    String sortBy = 'priority',
    bool onlyTravelRelevant = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final List<dynamic> args = [cityId];
    final List<String> conditions = ['city_id = ?'];

    if (category.toLowerCase() != 'all') {
      conditions.add('category = ?');
      args.add(category);
    }

    if (onlyTravelRelevant) {
      conditions.add('travel_relevance_score > 0.0');
    }

    String orderBy;
    switch (sortBy) {
      case 'name':
        orderBy = 'name ASC';
        break;
      case 'tier':
        orderBy = '''
          CASE tier 
            WHEN 'core_destination' THEN 1 
            WHEN 'recommended' THEN 2 
            WHEN 'discovery' THEN 3 
            ELSE 4 
          END, tourism_priority DESC
        ''';
        break;
      case 'relevance':
        orderBy = 'travel_relevance_score DESC, tourism_priority DESC';
        break;
      case 'priority':
      default:
        orderBy = 'tourism_priority DESC, travel_relevance_score DESC';
        break;
    }

    final whereClause = conditions.join(' AND ');
    final sql =
        '''
      SELECT * FROM places 
      WHERE $whereClause
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''';
    args.add(limit);
    args.add(offset);

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => LabPlace.fromMap(r)).toList();
  }

  Future<List<LabPlace>> getPlacesByTier(
    String tier, {
    int limit = 50,
    int offset = 0,
  }) async {
    final sql = '''
      SELECT * FROM places 
      WHERE city_id = ? AND tier = ?
      ORDER BY tourism_priority DESC, travel_relevance_score DESC
      LIMIT ? OFFSET ?
    ''';
    final rows = await db.rawQuery(sql, [cityId, tier, limit, offset]);
    return rows.map((r) => LabPlace.fromMap(r)).toList();
  }

  Future<List<LabPlace>> getPlacesInBounds(
    double minLat,
    double minLon,
    double maxLat,
    double maxLon, {
    String? category,
    String? tier,
    int limit = 200,
  }) async {
    final List<dynamic> args = [cityId, minLat, maxLat, minLon, maxLon];
    final List<String> conditions = [
      'city_id = ?',
      'latitude BETWEEN ? AND ?',
      'longitude BETWEEN ? AND ?',
    ];

    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'all') {
      conditions.add('category = ?');
      args.add(category);
    }
    if (tier != null && tier.isNotEmpty && tier.toLowerCase() != 'all') {
      conditions.add('tier = ?');
      args.add(tier);
    }

    final whereClause = conditions.join(' AND ');
    final sql =
        '''
      SELECT * FROM places 
      WHERE $whereClause
      ORDER BY tourism_priority DESC
      LIMIT ?
    ''';
    args.add(limit);

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => LabPlace.fromMap(r)).toList();
  }

  Future<List<LabPlace>> getAllPlacesForMap({
    String? category,
    String? tier,
    int limit = 500,
  }) async {
    final List<dynamic> args = [cityId];
    final List<String> conditions = ['city_id = ?'];

    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'all') {
      conditions.add('category = ?');
      args.add(category);
    }
    if (tier != null && tier.isNotEmpty && tier.toLowerCase() != 'all') {
      conditions.add('tier = ?');
      args.add(tier);
    }

    final whereClause = conditions.join(' AND ');
    final sql =
        '''
      SELECT * FROM places 
      WHERE $whereClause
      ORDER BY tourism_priority DESC
      LIMIT ?
    ''';
    args.add(limit);

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => LabPlace.fromMap(r)).toList();
  }

  Future<LabPlace?> getPlaceById(String id) async {
    final rows = await db.rawQuery(
      '''
      SELECT * FROM places WHERE id = ? LIMIT 1
    ''',
      [id],
    );

    if (rows.isEmpty) return null;
    final basePlace = LabPlace.fromMap(rows.first);

    // Fetch tags
    final tagRows = await db.rawQuery(
      '''
      SELECT tag FROM place_tags WHERE place_id = ?
    ''',
      [id],
    );
    final tags = tagRows.map((r) => r['tag'] as String).toList();

    // Fetch images
    final imgRows = await db.rawQuery(
      '''
      SELECT * FROM place_images WHERE place_id = ?
    ''',
      [id],
    );
    final images = imgRows.map((r) => PlaceImageItem.fromMap(r)).toList();

    // Fetch sources
    final srcRows = await db.rawQuery(
      '''
      SELECT * FROM place_sources WHERE place_id = ?
    ''',
      [id],
    );
    final sources = srcRows.map((r) => PlaceSourceItem.fromMap(r)).toList();

    return basePlace.copyWith(tags: tags, images: images, sources: sources);
  }

  Future<List<LabPlace>> getPlacesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT * FROM places WHERE id IN ($placeholders)
    ''', ids);
    return rows.map((r) => LabPlace.fromMap(r)).toList();
  }

  Future<List<LabPlace>> getRandomPlaces({
    int count = 50,
    String? tier,
    String? category,
    int seed = 42,
  }) async {
    final List<dynamic> args = [cityId];
    final List<String> conditions = ['city_id = ?'];

    if (tier != null && tier.isNotEmpty && tier.toLowerCase() != 'all') {
      conditions.add('tier = ?');
      args.add(tier);
    }
    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'all') {
      conditions.add('category = ?');
      args.add(category);
    }

    final whereClause = conditions.join(' AND ');
    final rows = await db.rawQuery('''
      SELECT id FROM places WHERE $whereClause
    ''', args);

    if (rows.isEmpty) return [];

    final idList = rows.map((r) => r['id'] as String).toList();
    // Deterministic shuffle using seed
    final rng = Random(seed);
    idList.shuffle(rng);

    final selectedIds = idList.take(count).toList();
    final places = await getPlacesByIds(selectedIds);
    // Keep the randomized order
    final placeMap = {for (var p in places) p.id: p};
    return selectedIds.map((id) => placeMap[id]).whereType<LabPlace>().toList();
  }

  Future<Map<String, dynamic>> getQualityStats() async {
    final totalRows = await db.rawQuery(
      'SELECT COUNT(*) as count FROM places WHERE city_id = ?',
      [cityId],
    );
    final totalPlaces = (totalRows.first['count'] as int?) ?? 0;

    final imgRows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM places 
      WHERE city_id = ? AND primary_image_path IS NOT NULL AND primary_image_path != ''
    ''',
      [cityId],
    );
    final withImages = (imgRows.first['count'] as int?) ?? 0;

    final wikiRows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM places 
      WHERE city_id = ? AND wikidata_id IS NOT NULL AND wikidata_id != ''
    ''',
      [cityId],
    );
    final withWikidata = (wikiRows.first['count'] as int?) ?? 0;

    final osmRows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM places 
      WHERE city_id = ? AND osm_id IS NOT NULL AND osm_id != ''
    ''',
      [cityId],
    );
    final withOsm = (osmRows.first['count'] as int?) ?? 0;

    final hoursRows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM places 
      WHERE city_id = ? AND opening_hours IS NOT NULL AND opening_hours != ''
    ''',
      [cityId],
    );
    final withHours = (hoursRows.first['count'] as int?) ?? 0;

    final webRows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM places 
      WHERE city_id = ? AND website IS NOT NULL AND website != ''
    ''',
      [cityId],
    );
    final withWebsite = (webRows.first['count'] as int?) ?? 0;

    final phoneRows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM places 
      WHERE city_id = ? AND phone IS NOT NULL AND phone != ''
    ''',
      [cityId],
    );
    final withPhone = (phoneRows.first['count'] as int?) ?? 0;

    // Boundary checks from cities table
    double? minLat, maxLat, minLon, maxLon;
    try {
      final cityRows = await db.rawQuery(
        'SELECT min_lat, max_lat, min_lon, max_lon FROM cities WHERE id = ? LIMIT 1',
        [cityId],
      );
      if (cityRows.isNotEmpty) {
        minLat = (cityRows.first['min_lat'] as num?)?.toDouble();
        maxLat = (cityRows.first['max_lat'] as num?)?.toDouble();
        minLon = (cityRows.first['min_lon'] as num?)?.toDouble();
        maxLon = (cityRows.first['max_lon'] as num?)?.toDouble();
      }
    } catch (_) {}

    // Core POI quality
    final coreRows = await db.rawQuery(
      "SELECT id, primary_image_path, opening_hours, wikidata_id, latitude, longitude FROM places WHERE city_id = ? AND tier = 'core_destination'",
      [cityId],
    );
    final coreTotal = coreRows.length;
    int coreWithImg = 0;
    int coreWithHours = 0;
    int coreWithWiki = 0;
    int coreOutsideBounds = 0;
    final List<String> coreMissingImgIds = [];
    final List<String> coreMissingHoursIds = [];
    final List<String> coreOutsideBoundsIds = [];

    for (final r in coreRows) {
      final id = r['id'] as String;
      final img = r['primary_image_path'] as String?;
      final hours = r['opening_hours'] as String?;
      final wiki = r['wikidata_id'] as String?;
      final lat = (r['latitude'] as num?)?.toDouble();
      final lon = (r['longitude'] as num?)?.toDouble();

      if (img != null && img.isNotEmpty) {
        coreWithImg++;
      } else {
        coreMissingImgIds.add(id);
      }

      if (hours != null && hours.isNotEmpty) {
        coreWithHours++;
      } else {
        coreMissingHoursIds.add(id);
      }

      if (wiki != null && wiki.isNotEmpty) {
        coreWithWiki++;
      }

      if (minLat != null &&
          maxLat != null &&
          minLon != null &&
          maxLon != null &&
          lat != null &&
          lon != null) {
        if (lat < minLat || lat > maxLat || lon < minLon || lon > maxLon) {
          coreOutsideBounds++;
          coreOutsideBoundsIds.add(id);
        }
      }
    }

    // All places outside bounding box
    int placesOutsideBounds = 0;
    List<String> outsideBoundsIds = [];
    if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
      final outsideRows = await db.rawQuery(
        '''
        SELECT id FROM places 
        WHERE city_id = ? AND (latitude < ? OR latitude > ? OR longitude < ? OR longitude > ?)
      ''',
        [cityId, minLat, maxLat, minLon, maxLon],
      );
      placesOutsideBounds = outsideRows.length;
      outsideBoundsIds = outsideRows.map((r) => r['id'] as String).toList();
    }

    // Duplicate coordinate clusters
    int sharedCoordsCount = 0;
    List<String> sharedCoordsIds = [];
    try {
      final dupRows = await db.rawQuery(
        '''
        SELECT id FROM places 
        WHERE city_id = ? AND (latitude, longitude) IN (
          SELECT latitude, longitude FROM places 
          WHERE city_id = ? AND latitude IS NOT NULL AND longitude IS NOT NULL
          GROUP BY latitude, longitude HAVING COUNT(*) > 1
        )
      ''',
        [cityId, cityId],
      );
      sharedCoordsCount = dupRows.length;
      sharedCoordsIds = dupRows.map((r) => r['id'] as String).toList();
    } catch (_) {}

    // Multi-source provenance
    int multiSourceCount = 0;
    try {
      final multiSrcRows = await db.rawQuery('''
        SELECT COUNT(*) as count FROM (
          SELECT place_id FROM place_sources 
          GROUP BY place_id HAVING COUNT(*) > 1
        )
      ''');
      multiSourceCount = (multiSrcRows.first['count'] as int?) ?? 0;
    } catch (_) {
      final fallbackRows = await db.rawQuery(
        '''
        SELECT COUNT(*) as count FROM places 
        WHERE city_id = ? AND wikidata_id IS NOT NULL AND wikidata_id != '' AND osm_id IS NOT NULL AND osm_id != ''
      ''',
        [cityId],
      );
      multiSourceCount = (fallbackRows.first['count'] as int?) ?? 0;
    }

    final tierCounts = await getTiersWithCounts();
    final categoryCounts = await getCategoriesWithCounts();
    final mediaLicenses = await db.rawQuery(
      "SELECT COUNT(*) AS n FROM place_images WHERE license IS NULL OR trim(license) = '' OR lower(license) IN ('unknown', 'unverified')",
    );
    final categoryValidity = await db.rawQuery(
      "SELECT COUNT(*) AS n FROM places WHERE category IS NOT NULL AND trim(category) != '' AND lower(category) NOT IN ('unknown', 'uncategorized')",
    );

    return {
      'total_places': totalPlaces,
      'with_images': withImages,
      'without_images': totalPlaces - withImages,
      'with_wikidata': withWikidata,
      'with_osm': withOsm,
      'with_opening_hours': withHours,
      'with_website': withWebsite,
      'with_phone': withPhone,
      'tier_counts': tierCounts,
      'category_counts': categoryCounts,
      'core_total': coreTotal,
      'core_with_images': coreWithImg,
      'core_with_hours': coreWithHours,
      'core_with_wikidata': coreWithWiki,
      'core_outside_bounds': coreOutsideBounds,
      'core_missing_image_ids': coreMissingImgIds,
      'core_missing_hours_ids': coreMissingHoursIds,
      'core_outside_bounds_ids': coreOutsideBoundsIds,
      'places_outside_bounds': placesOutsideBounds,
      'outside_bounds_ids': outsideBoundsIds,
      'shared_coords_places_count': sharedCoordsCount,
      'shared_coords_ids': sharedCoordsIds,
      'multi_source_count': multiSourceCount,
      'places_with_valid_category': categoryValidity.first['n'] as int,
      'media_missing_license_count': mediaLicenses.first['n'] as int,
      'bbox': {
        'min_lat': minLat,
        'max_lat': maxLat,
        'min_lon': minLon,
        'max_lon': maxLon,
      },
    };
  }

  Future<List<Map<String, dynamic>>> getCategoryCoverageMatrix() async {
    const sql = '''
      SELECT 
        category, 
        COUNT(*) as total,
        SUM(CASE WHEN primary_image_path IS NOT NULL AND primary_image_path != '' THEN 1 ELSE 0 END) as with_images,
        SUM(CASE WHEN opening_hours IS NOT NULL AND opening_hours != '' THEN 1 ELSE 0 END) as with_hours,
        SUM(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL AND latitude != 0 AND longitude != 0 THEN 1 ELSE 0 END) as with_geo,
        SUM(CASE WHEN (website IS NOT NULL AND website != '') OR (phone IS NOT NULL AND phone != '') THEN 1 ELSE 0 END) as with_details
      FROM places
      WHERE city_id = ?
      GROUP BY category
      ORDER BY total DESC
    ''';
    final rows = await db.rawQuery(sql, [cityId]);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<LabPlace>> getPlacesForGap(
    String filterPreset, {
    int limit = 50,
    int offset = 0,
    String? category,
  }) async {
    final List<dynamic> args = [cityId];
    String condition = '';

    switch (filterPreset) {
      case 'core_missing_images':
        condition = "tier = 'core_destination' AND (primary_image_path IS NULL OR primary_image_path = '')";
        break;
      case 'core_missing_hours':
        condition = "tier = 'core_destination' AND (opening_hours IS NULL OR opening_hours = '')";
        break;
      case 'core_geo_issue':
        // Retrieve bbox
        double? minLat, maxLat, minLon, maxLon;
        try {
          final cityRows = await db.rawQuery(
            'SELECT min_lat, max_lat, min_lon, max_lon FROM cities WHERE id = ? LIMIT 1',
            [cityId],
          );
          if (cityRows.isNotEmpty) {
            minLat = (cityRows.first['min_lat'] as num?)?.toDouble();
            maxLat = (cityRows.first['max_lat'] as num?)?.toDouble();
            minLon = (cityRows.first['min_lon'] as num?)?.toDouble();
            maxLon = (cityRows.first['max_lon'] as num?)?.toDouble();
          }
        } catch (_) {}
        if (minLat != null &&
            maxLat != null &&
            minLon != null &&
            maxLon != null) {
          condition = "tier = 'core_destination' AND (latitude < ? OR latitude > ? OR longitude < ? OR longitude > ?)";
          args.addAll([minLat, maxLat, minLon, maxLon]);
        } else {
          condition = "tier = 'core_destination' AND 1=0";
        }
        break;
      case 'geo_outliers':
        double? minLat, maxLat, minLon, maxLon;
        try {
          final cityRows = await db.rawQuery(
            'SELECT min_lat, max_lat, min_lon, max_lon FROM cities WHERE id = ? LIMIT 1',
            [cityId],
          );
          if (cityRows.isNotEmpty) {
            minLat = (cityRows.first['min_lat'] as num?)?.toDouble();
            maxLat = (cityRows.first['max_lat'] as num?)?.toDouble();
            minLon = (cityRows.first['min_lon'] as num?)?.toDouble();
            maxLon = (cityRows.first['max_lon'] as num?)?.toDouble();
          }
        } catch (_) {}
        if (minLat != null &&
            maxLat != null &&
            minLon != null &&
            maxLon != null) {
          condition = "(latitude < ? OR latitude > ? OR longitude < ? OR longitude > ?)";
          args.addAll([minLat, maxLat, minLon, maxLon]);
        } else {
          condition = "1=0";
        }
        break;
      case 'duplicate_coords':
        condition = '''
          (latitude, longitude) IN (
            SELECT latitude, longitude FROM places 
            WHERE city_id = ? AND latitude IS NOT NULL AND longitude IS NOT NULL
            GROUP BY latitude, longitude HAVING COUNT(*) > 1
          )
        ''';
        args.add(cityId);
        break;
      case 'missing_images':
        condition = "(primary_image_path IS NULL OR primary_image_path = '')";
        break;
      case 'missing_hours':
        condition = "(opening_hours IS NULL OR opening_hours = '')";
        break;
      case 'single_source':
        condition = '''
          id NOT IN (
            SELECT place_id FROM place_sources 
            GROUP BY place_id HAVING COUNT(*) > 1
          )
        ''';
        break;
      default:
        condition = "1=1";
        break;
    }

    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'all') {
      condition += " AND category = ?";
      args.add(category);
    }

    final sql =
        '''
      SELECT * FROM places 
      WHERE city_id = ? AND $condition
      ORDER BY tourism_priority DESC, name ASC
      LIMIT ? OFFSET ?
    ''';
    args.add(limit);
    args.add(offset);

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => LabPlace.fromMap(r)).toList();
  }
}
