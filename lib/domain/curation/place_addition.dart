import 'dart:convert';
import '../lab_place.dart';

/// Represents a completely missing place added by a human curator.
/// Saved deterministically as an entity-level JSON file in:
/// `assets/city_packs/<city>/curation/additions/<place_id>.json`
class PlaceAddition {
  final String id;
  final String cityId;
  final String name;
  final String? nameHi;
  final String category;
  final String? subcategory;
  final String tier; // core_destination, recommended, discovery
  final double latitude;
  final double longitude;
  final String? address;
  final String? openingHours;
  final String? website;
  final String? phone;
  final String? description;
  final String? primaryImagePath;
  final int? recommendedVisitMinutes;
  final int? familyFriendly;
  final String? bestTime;

  /// Provenance metadata
  final String author;
  final String createdAt;
  final String evidenceSource; // URL, physical visit, government registry
  final String? notes;

  const PlaceAddition({
    required this.id,
    required this.cityId,
    required this.name,
    this.nameHi,
    required this.category,
    this.subcategory,
    this.tier = 'recommended',
    required this.latitude,
    required this.longitude,
    this.address,
    this.openingHours,
    this.website,
    this.phone,
    this.description,
    this.primaryImagePath,
    this.recommendedVisitMinutes,
    this.familyFriendly,
    this.bestTime,
    required this.author,
    required this.createdAt,
    required this.evidenceSource,
    this.notes,
  });

  LabPlace toLabPlace() {
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
      tier: tier,
      travelRelevanceScore: tier == 'core_destination' ? 0.95 : 0.80,
      prominenceScore: tier == 'core_destination' ? 0.90 : 0.70,
      recommendedVisitMinutes: recommendedVisitMinutes,
      familyFriendly: familyFriendly,
      bestTime: bestTime,
      website: website,
      phone: phone,
      openingHours: openingHours,
      primaryImagePath: primaryImagePath,
      generatedAt: createdAt,
      sources: [
        PlaceSourceItem(
          id: 0,
          placeId: id,
          source: 'manual_curation',
          sourceId: author,
          retrievedAt: createdAt,
        ),
      ],
      tags: ['manual_addition', category],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'city_id': cityId,
      'name': name,
      'category': category,
      'tier': tier,
      'latitude': latitude,
      'longitude': longitude,
      'author': author,
      'created_at': createdAt,
      'evidence_source': evidenceSource,
    };

    if (nameHi != null) map['name_hi'] = nameHi;
    if (subcategory != null) map['subcategory'] = subcategory;
    if (address != null) map['address'] = address;
    if (openingHours != null) map['opening_hours'] = openingHours;
    if (website != null) map['website'] = website;
    if (phone != null) map['phone'] = phone;
    if (description != null) map['description'] = description;
    if (primaryImagePath != null) map['primary_image_path'] = primaryImagePath;
    if (recommendedVisitMinutes != null) map['recommended_visit_minutes'] = recommendedVisitMinutes;
    if (familyFriendly != null) map['family_friendly'] = familyFriendly;
    if (bestTime != null) map['best_time'] = bestTime;
    if (notes != null) map['notes'] = notes;

    return map;
  }

  factory PlaceAddition.fromJson(Map<String, dynamic> json) {
    return PlaceAddition(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      name: json['name'] as String,
      nameHi: json['name_hi'] as String?,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      tier: json['tier'] as String? ?? 'recommended',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      openingHours: json['opening_hours'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      primaryImagePath: json['primary_image_path'] as String?,
      recommendedVisitMinutes: json['recommended_visit_minutes'] as int?,
      familyFriendly: json['family_friendly'] as int?,
      bestTime: json['best_time'] as String?,
      author: json['author'] as String? ?? 'contributor',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      evidenceSource: json['evidence_source'] as String? ?? 'manual_input',
      notes: json['notes'] as String?,
    );
  }

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
