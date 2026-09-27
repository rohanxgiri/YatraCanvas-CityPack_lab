class PlaceImageItem {
  final int id;
  final String placeId;
  final String originalFile;
  final String localPath;
  final String? thumbnailPath;
  final String? author;
  final String license;
  final String? licenseUrl;
  final String? attribution;
  final String? matchMethod;
  final double? matchConfidence;

  const PlaceImageItem({
    required this.id,
    required this.placeId,
    required this.originalFile,
    required this.localPath,
    this.thumbnailPath,
    this.author,
    required this.license,
    this.licenseUrl,
    this.attribution,
    this.matchMethod,
    this.matchConfidence,
  });

  factory PlaceImageItem.fromMap(Map<String, dynamic> map) {
    return PlaceImageItem(
      id: map['id'] as int? ?? 0,
      placeId: map['place_id'] as String? ?? '',
      originalFile: map['original_file'] as String? ?? '',
      localPath: map['local_path'] as String? ?? '',
      thumbnailPath: map['thumbnail_path'] as String?,
      author: map['author'] as String?,
      license: map['license'] as String? ?? 'Unknown',
      licenseUrl: map['license_url'] as String?,
      attribution: map['attribution'] as String?,
      matchMethod: map['match_method'] as String?,
      matchConfidence: (map['match_confidence'] as num?)?.toDouble(),
    );
  }
}

class PlaceSourceItem {
  final int id;
  final String placeId;
  final String source;
  final String? sourceId;
  final String? retrievedAt;

  const PlaceSourceItem({
    required this.id,
    required this.placeId,
    required this.source,
    this.sourceId,
    this.retrievedAt,
  });

  factory PlaceSourceItem.fromMap(Map<String, dynamic> map) {
    return PlaceSourceItem(
      id: map['id'] as int? ?? 0,
      placeId: map['place_id'] as String? ?? '',
      source: map['source'] as String? ?? '',
      sourceId: map['source_id'] as String?,
      retrievedAt: map['retrieved_at'] as String?,
    );
  }
}

class LabPlace {
  final String id;
  final String cityId;
  final String name;
  final String? nameHi;
  final double latitude;
  final double longitude;
  final String? address;
  final String category;
  final String? subcategory;
  final String? primaryEntityType;
  final String tier;
  final double travelRelevanceScore;
  final double prominenceScore;
  final int? recommendedVisitMinutes;
  final double? tourismPriority;
  final int? familyFriendly;
  final String? bestTime;
  final String? website;
  final String? phone;
  final String? openingHours;
  final String? overtureId;
  final String? osmId;
  final String? wikidataId;
  final String? foursquareId;
  final String? wikivoyageListingId;
  final double? qualityOverall;
  final double anomalyScore;
  final String? primaryImagePath;
  final String? thumbnailImagePath;
  final String? generatedAt;
  final List<String> tags;
  final List<PlaceImageItem> images;
  final List<PlaceSourceItem> sources;

  const LabPlace({
    required this.id,
    required this.cityId,
    required this.name,
    this.nameHi,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.category,
    this.subcategory,
    this.primaryEntityType,
    required this.tier,
    required this.travelRelevanceScore,
    required this.prominenceScore,
    this.recommendedVisitMinutes,
    this.tourismPriority,
    this.familyFriendly,
    this.bestTime,
    this.website,
    this.phone,
    this.openingHours,
    this.overtureId,
    this.osmId,
    this.wikidataId,
    this.foursquareId,
    this.wikivoyageListingId,
    this.qualityOverall,
    this.anomalyScore = 0.0,
    this.primaryImagePath,
    this.thumbnailImagePath,
    this.generatedAt,
    this.tags = const [],
    this.images = const [],
    this.sources = const [],
  });

  bool get hasImage =>
      (primaryImagePath != null && primaryImagePath!.isNotEmpty) ||
      images.isNotEmpty;

  factory LabPlace.fromMap(
    Map<String, dynamic> map, {
    List<String> tags = const [],
    List<PlaceImageItem> images = const [],
    List<PlaceSourceItem> sources = const [],
  }) {
    return LabPlace(
      id: map['id'] as String,
      cityId: map['city_id'] as String,
      name: map['name'] as String,
      nameHi: map['name_hi'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String?,
      category: map['category'] as String,
      subcategory: map['subcategory'] as String?,
      primaryEntityType: map['primary_entity_type'] as String?,
      tier: map['tier'] as String? ?? 'discovery',
      travelRelevanceScore: (map['travel_relevance_score'] as num?)?.toDouble() ?? 0.0,
      prominenceScore: (map['prominence_score'] as num?)?.toDouble() ?? 0.0,
      recommendedVisitMinutes: map['recommended_visit_minutes'] as int?,
      tourismPriority: (map['tourism_priority'] as num?)?.toDouble(),
      familyFriendly: map['family_friendly'] as int?,
      bestTime: map['best_time'] as String?,
      website: map['website'] as String?,
      phone: map['phone'] as String?,
      openingHours: map['opening_hours'] as String?,
      overtureId: map['overture_id'] as String?,
      osmId: map['osm_id'] as String?,
      wikidataId: map['wikidata_id'] as String?,
      foursquareId: map['foursquare_id'] as String?,
      wikivoyageListingId: map['wikivoyage_listing_id'] as String?,
      qualityOverall: (map['quality_overall'] as num?)?.toDouble(),
      anomalyScore: (map['anomaly_score'] as num?)?.toDouble() ?? 0.0,
      primaryImagePath: map['primary_image_path'] as String?,
      thumbnailImagePath: map['thumbnail_image_path'] as String?,
      generatedAt: map['generated_at'] as String?,
      tags: tags,
      images: images,
      sources: sources,
    );
  }

  bool get hasLocalImage =>
      primaryImagePath != null && primaryImagePath!.trim().isNotEmpty;

  LabPlace copyWith({
    List<String>? tags,
    List<PlaceImageItem>? images,
    List<PlaceSourceItem>? sources,
  }) {
    return LabPlace(
      id: id,
      cityId: cityId,
      name: name,
      nameHi: nameHi,
      latitude: latitude,
      longitude: longitude,
      address: address,
      category: category,
      subcategory: subcategory,
      primaryEntityType: primaryEntityType,
      tier: tier,
      travelRelevanceScore: travelRelevanceScore,
      prominenceScore: prominenceScore,
      recommendedVisitMinutes: recommendedVisitMinutes,
      tourismPriority: tourismPriority,
      familyFriendly: familyFriendly,
      bestTime: bestTime,
      website: website,
      phone: phone,
      openingHours: openingHours,
      overtureId: overtureId,
      osmId: osmId,
      wikidataId: wikidataId,
      foursquareId: foursquareId,
      wikivoyageListingId: wikivoyageListingId,
      qualityOverall: qualityOverall,
      anomalyScore: anomalyScore,
      primaryImagePath: primaryImagePath,
      thumbnailImagePath: thumbnailImagePath,
      generatedAt: generatedAt,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      sources: sources ?? this.sources,
    );
  }
}
