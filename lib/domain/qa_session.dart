import 'qa_issue.dart';

class RandomReviewRecord {
  final String placeId;
  final String placeName;
  final String tier;
  final String category;
  final String result; // 'looks_good' or QaIssueType code
  final String? note;
  final String timestamp;

  const RandomReviewRecord({
    required this.placeId,
    required this.placeName,
    required this.tier,
    required this.category,
    required this.result,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'place_id': placeId,
        'place_name': placeName,
        'tier': tier,
        'category': category,
        'result': result,
        'note': note,
        'timestamp': timestamp,
      };

  factory RandomReviewRecord.fromJson(Map<String, dynamic> json) {
    return RandomReviewRecord(
      placeId: json['place_id'] as String,
      placeName: json['place_name'] as String,
      tier: json['tier'] as String? ?? 'discovery',
      category: json['category'] as String? ?? 'general',
      result: json['result'] as String,
      note: json['note'] as String?,
      timestamp: json['timestamp'] as String,
    );
  }
}

class SearchResultReviewRecord {
  final String query;
  final int rank;
  final String placeId;
  final String placeName;
  final String rating; // 'relevant', 'partially_relevant', 'irrelevant', 'unsure'
  final String timestamp;

  const SearchResultReviewRecord({
    required this.query,
    required this.rank,
    required this.placeId,
    required this.placeName,
    required this.rating,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'rank': rank,
        'place_id': placeId,
        'place_name': placeName,
        'rating': rating,
        'timestamp': timestamp,
      };

  factory SearchResultReviewRecord.fromJson(Map<String, dynamic> json) {
    return SearchResultReviewRecord(
      query: json['query'] as String,
      rank: json['rank'] as int,
      placeId: json['place_id'] as String,
      placeName: json['place_name'] as String,
      rating: json['rating'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}

class ExpectedPlaceCheckRecord {
  final String query;
  final String? placeId;
  final String? placeName;
  final String status; // 'found', 'found_but_wrong', 'not_found'
  final String? note;
  final String timestamp;

  const ExpectedPlaceCheckRecord({
    required this.query,
    this.placeId,
    this.placeName,
    required this.status,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'place_id': placeId,
        'place_name': placeName,
        'status': status,
        'note': note,
        'timestamp': timestamp,
      };

  factory ExpectedPlaceCheckRecord.fromJson(Map<String, dynamic> json) {
    return ExpectedPlaceCheckRecord(
      query: json['query'] as String,
      placeId: json['place_id'] as String?,
      placeName: json['place_name'] as String?,
      status: json['status'] as String,
      note: json['note'] as String?,
      timestamp: json['timestamp'] as String,
    );
  }
}

class ScenarioResultRecord {
  final String scenarioName;
  final int days;
  final List<String> interests;
  final int selectedPlacesCount;
  final String trusted; // 'yes', 'mostly', 'no'
  final String notes;
  final String timestamp;

  const ScenarioResultRecord({
    required this.scenarioName,
    required this.days,
    required this.interests,
    required this.selectedPlacesCount,
    required this.trusted,
    required this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'scenario_name': scenarioName,
        'days': days,
        'interests': interests,
        'selected_places_count': selectedPlacesCount,
        'trusted': trusted,
        'notes': notes,
        'timestamp': timestamp,
      };

  factory ScenarioResultRecord.fromJson(Map<String, dynamic> json) {
    return ScenarioResultRecord(
      scenarioName: json['scenario_name'] as String,
      days: json['days'] as int? ?? 3,
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      selectedPlacesCount: json['selected_places_count'] as int? ?? 0,
      trusted: json['trusted'] as String? ?? 'mostly',
      notes: json['notes'] as String? ?? '',
      timestamp: json['timestamp'] as String,
    );
  }
}

class QaSession {
  final String cityId;
  final String packVersion;
  final String createdAt;
  String lastModified;
  final List<QaIssue> issues;
  final List<RandomReviewRecord> randomReviews;
  final List<SearchResultReviewRecord> searchReviews;
  final List<ExpectedPlaceCheckRecord> expectedPlaceChecks;
  final List<ScenarioResultRecord> scenarioResults;
  final Map<String, int> tripSelections; // placeId -> day (1..7)

  QaSession({
    required this.cityId,
    required this.packVersion,
    required this.createdAt,
    required this.lastModified,
    List<QaIssue>? issues,
    List<RandomReviewRecord>? randomReviews,
    List<SearchResultReviewRecord>? searchReviews,
    List<ExpectedPlaceCheckRecord>? expectedPlaceChecks,
    List<ScenarioResultRecord>? scenarioResults,
    Map<String, int>? tripSelections,
  })  : issues = issues ?? [],
        randomReviews = randomReviews ?? [],
        searchReviews = searchReviews ?? [],
        expectedPlaceChecks = expectedPlaceChecks ?? [],
        scenarioResults = scenarioResults ?? [],
        tripSelections = tripSelections ?? {};

  Map<String, dynamic> toJson() => {
        'city_id': cityId,
        'pack_version': packVersion,
        'created_at': createdAt,
        'last_modified': lastModified,
        'issues': issues.map((e) => e.toJson()).toList(),
        'random_reviews': randomReviews.map((e) => e.toJson()).toList(),
        'search_reviews': searchReviews.map((e) => e.toJson()).toList(),
        'expected_place_checks': expectedPlaceChecks.map((e) => e.toJson()).toList(),
        'scenario_results': scenarioResults.map((e) => e.toJson()).toList(),
        'trip_selections': tripSelections,
      };

  factory QaSession.fromJson(Map<String, dynamic> json) {
    return QaSession(
      cityId: json['city_id'] as String,
      packVersion: json['pack_version'] as String? ?? 'v3',
      createdAt: json['created_at'] as String,
      lastModified: json['last_modified'] as String,
      issues: (json['issues'] as List<dynamic>?)
              ?.map((e) => QaIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      randomReviews: (json['random_reviews'] as List<dynamic>?)
              ?.map((e) => RandomReviewRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      searchReviews: (json['search_reviews'] as List<dynamic>?)
              ?.map((e) => SearchResultReviewRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      expectedPlaceChecks: (json['expected_place_checks'] as List<dynamic>?)
              ?.map((e) => ExpectedPlaceCheckRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      scenarioResults: (json['scenario_results'] as List<dynamic>?)
              ?.map((e) => ScenarioResultRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tripSelections: (json['trip_selections'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }
}
