import 'dart:convert';

/// Represents an individual verification decision in the Manual QA workflow.
/// Stored deterministically as an entity-level JSON file in:
/// `assets/city_packs/<city>/curation/reviews/<place_id>.json`
class PlaceReview {
  final String id;
  final String placeId;
  final String cityId;
  final String placeName;
  final String tier;
  final String category;
  final String verdict; // 'looks_good' or defect code (e.g. 'wrong_image', 'wrong_location')
  final String? issueType;
  final String? notes;
  final String reviewer;
  final String timestamp;

  const PlaceReview({
    required this.id,
    required this.placeId,
    required this.cityId,
    required this.placeName,
    required this.tier,
    required this.category,
    required this.verdict,
    this.issueType,
    this.notes,
    required this.reviewer,
    required this.timestamp,
  });

  bool get isApproved => verdict == 'looks_good';

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'place_id': placeId,
      'city_id': cityId,
      'place_name': placeName,
      'tier': tier,
      'category': category,
      'verdict': verdict,
      'reviewer': reviewer,
      'timestamp': timestamp,
    };
    if (issueType != null) map['issue_type'] = issueType;
    if (notes != null) map['notes'] = notes;
    return map;
  }

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    return PlaceReview(
      id: json['id'] as String? ?? 'rev_${json['place_id']}',
      placeId: json['place_id'] as String,
      cityId: json['city_id'] as String? ?? '',
      placeName: json['place_name'] as String? ?? 'Unknown',
      tier: json['tier'] as String? ?? 'discovery',
      category: json['category'] as String? ?? 'general',
      verdict: json['verdict'] as String? ?? 'looks_good',
      issueType: json['issue_type'] as String?,
      notes: json['notes'] as String?,
      reviewer: json['reviewer'] as String? ?? 'contributor',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
