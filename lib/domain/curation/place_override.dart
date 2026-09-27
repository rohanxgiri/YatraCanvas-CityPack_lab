import 'dart:convert';

/// Represents a human field-level override for an existing generated place.
/// Saved deterministically as an entity-level JSON file in:
/// `assets/city_packs/<city>/curation/overrides/<place_id>.json`
class PlaceOverride {
  final String placeId;
  final String cityId;
  final String packVersion;
  final String? name;
  final String? nameHi;
  final String? category;
  final String? subcategory;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? openingHours;
  final String? website;
  final String? phone;
  final String? description;
  final String? primaryImagePath;
  final String? tier;
  final bool? isCore;

  /// Audit & provenance metadata
  final Map<String, String> fieldSources;
  final Map<String, dynamic> previousValues;
  final String author;
  final String updatedAt;
  final bool verified;
  final String? reviewNotes;

  const PlaceOverride({
    required this.placeId,
    required this.cityId,
    required this.packVersion,
    this.name,
    this.nameHi,
    this.category,
    this.subcategory,
    this.latitude,
    this.longitude,
    this.address,
    this.openingHours,
    this.website,
    this.phone,
    this.description,
    this.primaryImagePath,
    this.tier,
    this.isCore,
    this.fieldSources = const {},
    this.previousValues = const {},
    required this.author,
    required this.updatedAt,
    this.verified = true,
    this.reviewNotes,
  });

  bool get hasChanges =>
      name != null ||
      nameHi != null ||
      category != null ||
      subcategory != null ||
      latitude != null ||
      longitude != null ||
      address != null ||
      openingHours != null ||
      website != null ||
      phone != null ||
      description != null ||
      primaryImagePath != null ||
      tier != null ||
      isCore != null;

  PlaceOverride copyWith({
    String? name,
    String? nameHi,
    String? category,
    String? subcategory,
    double? latitude,
    double? longitude,
    String? address,
    String? openingHours,
    String? website,
    String? phone,
    String? description,
    String? primaryImagePath,
    String? tier,
    bool? isCore,
    Map<String, String>? fieldSources,
    Map<String, dynamic>? previousValues,
    String? author,
    String? updatedAt,
    bool? verified,
    String? reviewNotes,
  }) {
    return PlaceOverride(
      placeId: placeId,
      cityId: cityId,
      packVersion: packVersion,
      name: name ?? this.name,
      nameHi: nameHi ?? this.nameHi,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      openingHours: openingHours ?? this.openingHours,
      website: website ?? this.website,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      primaryImagePath: primaryImagePath ?? this.primaryImagePath,
      tier: tier ?? this.tier,
      isCore: isCore ?? this.isCore,
      fieldSources: fieldSources ?? this.fieldSources,
      previousValues: previousValues ?? this.previousValues,
      author: author ?? this.author,
      updatedAt: updatedAt ?? this.updatedAt,
      verified: verified ?? this.verified,
      reviewNotes: reviewNotes ?? this.reviewNotes,
    );
  }

  Map<String, dynamic> toJson() {
    // Deterministic sorted map structure for Git-friendly diffs
    final map = <String, dynamic>{
      'place_id': placeId,
      'city_id': cityId,
      'pack_version': packVersion,
      'author': author,
      'updated_at': updatedAt,
      'verified': verified,
    };

    if (name != null) map['name'] = name;
    if (nameHi != null) map['name_hi'] = nameHi;
    if (category != null) map['category'] = category;
    if (subcategory != null) map['subcategory'] = subcategory;
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    if (address != null) map['address'] = address;
    if (openingHours != null) map['opening_hours'] = openingHours;
    if (website != null) map['website'] = website;
    if (phone != null) map['phone'] = phone;
    if (description != null) map['description'] = description;
    if (primaryImagePath != null) map['primary_image_path'] = primaryImagePath;
    if (tier != null) map['tier'] = tier;
    if (isCore != null) map['is_core'] = isCore;
    if (reviewNotes != null) map['review_notes'] = reviewNotes;

    if (fieldSources.isNotEmpty) map['field_sources'] = fieldSources;
    if (previousValues.isNotEmpty) map['previous_values'] = previousValues;

    return map;
  }

  factory PlaceOverride.fromJson(Map<String, dynamic> json) {
    return PlaceOverride(
      placeId: json['place_id'] as String,
      cityId: json['city_id'] as String,
      packVersion: json['pack_version'] as String? ?? 'v3',
      name: json['name'] as String?,
      nameHi: json['name_hi'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      openingHours: json['opening_hours'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      primaryImagePath: json['primary_image_path'] as String?,
      tier: json['tier'] as String?,
      isCore: json['is_core'] as bool?,
      fieldSources: (json['field_sources'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      previousValues: (json['previous_values'] as Map<String, dynamic>?) ?? {},
      author: json['author'] as String? ?? 'contributor',
      updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      verified: json['verified'] as bool? ?? true,
      reviewNotes: json['review_notes'] as String?,
    );
  }

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
