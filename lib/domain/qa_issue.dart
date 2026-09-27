enum QaIssueType {
  wrongCategory,
  wrongSubcategory,
  wrongEntityType,
  wrongName,
  wrongLocation,
  wrongImage,
  duplicate,
  notTravelRelevant,
  shouldNotBeCore,
  missingExpectedInformation,
  possiblyClosedOrStale,
  other;

  String get code {
    switch (this) {
      case QaIssueType.wrongCategory:
        return 'wrong_category';
      case QaIssueType.wrongSubcategory:
        return 'wrong_subcategory';
      case QaIssueType.wrongEntityType:
        return 'wrong_entity_type';
      case QaIssueType.wrongName:
        return 'wrong_name';
      case QaIssueType.wrongLocation:
        return 'wrong_location';
      case QaIssueType.wrongImage:
        return 'wrong_image';
      case QaIssueType.duplicate:
        return 'duplicate';
      case QaIssueType.notTravelRelevant:
        return 'not_travel_relevant';
      case QaIssueType.shouldNotBeCore:
        return 'should_not_be_core';
      case QaIssueType.missingExpectedInformation:
        return 'missing_expected_information';
      case QaIssueType.possiblyClosedOrStale:
        return 'possibly_closed_or_stale';
      case QaIssueType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case QaIssueType.wrongCategory:
        return 'Wrong Category';
      case QaIssueType.wrongSubcategory:
        return 'Wrong Subcategory';
      case QaIssueType.wrongEntityType:
        return 'Wrong Entity Type';
      case QaIssueType.wrongName:
        return 'Wrong Name';
      case QaIssueType.wrongLocation:
        return 'Wrong Location';
      case QaIssueType.wrongImage:
        return 'Wrong / Bad Image';
      case QaIssueType.duplicate:
        return 'Duplicate POI';
      case QaIssueType.notTravelRelevant:
        return 'Not Travel Relevant';
      case QaIssueType.shouldNotBeCore:
        return 'Should Not Be Core';
      case QaIssueType.missingExpectedInformation:
        return 'Missing Expected Info';
      case QaIssueType.possiblyClosedOrStale:
        return 'Possibly Closed / Stale';
      case QaIssueType.other:
        return 'Other Issue';
    }
  }

  static QaIssueType fromCode(String code) {
    for (final val in QaIssueType.values) {
      if (val.code == code || val.name == code) {
        return val;
      }
    }
    return QaIssueType.other;
  }
}

class QaIssue {
  final String id;
  final String timestamp;
  final String cityId;
  final String packVersion;
  final String placeId;
  final String placeName;
  final String tier;
  final String category;
  final double latitude;
  final double longitude;
  final QaIssueType issueType;
  final String note;

  const QaIssue({
    required this.id,
    required this.timestamp,
    required this.cityId,
    required this.packVersion,
    required this.placeId,
    required this.placeName,
    required this.tier,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.issueType,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'city_id': cityId,
        'pack_version': packVersion,
        'place_id': placeId,
        'place_name': placeName,
        'tier': tier,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'issue_type': issueType.code,
        'note': note,
      };

  factory QaIssue.fromJson(Map<String, dynamic> json) {
    return QaIssue(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      cityId: json['city_id'] as String,
      packVersion: json['pack_version'] as String? ?? 'v3',
      placeId: json['place_id'] as String,
      placeName: json['place_name'] as String,
      tier: json['tier'] as String? ?? 'discovery',
      category: json['category'] as String? ?? 'unknown',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      issueType: QaIssueType.fromCode(json['issue_type'] as String? ?? 'other'),
      note: json['note'] as String? ?? '',
    );
  }
}
