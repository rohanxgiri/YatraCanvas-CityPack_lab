import 'dart:convert';

/// Represents an exclusion of an inappropriate, closed, or restricted POI.
/// Stored deterministically as an entity-level JSON file in:
/// `assets/city_packs/<city>/curation/exclusions/<place_id>.json`
class PlaceExclusion {
  final String placeId;
  final String cityId;
  final String placeName;
  final String reason; // closed_permanently, restricted_private, duplicate, institutional_canteen, non_tourist_utility, bad_source, other
  final String? notes;
  final String excludedBy;
  final String timestamp;

  const PlaceExclusion({
    required this.placeId,
    required this.cityId,
    required this.placeName,
    required this.reason,
    this.notes,
    required this.excludedBy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'place_id': placeId,
      'city_id': cityId,
      'place_name': placeName,
      'reason': reason,
      'excluded_by': excludedBy,
      'timestamp': timestamp,
    };
    if (notes != null) map['notes'] = notes;
    return map;
  }

  factory PlaceExclusion.fromJson(Map<String, dynamic> json) {
    return PlaceExclusion(
      placeId: json['place_id'] as String,
      cityId: json['city_id'] as String,
      placeName: json['place_name'] as String? ?? 'Unnamed Place',
      reason: json['reason'] as String? ?? 'other',
      notes: json['notes'] as String?,
      excludedBy: json['excluded_by'] as String? ?? 'contributor',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
