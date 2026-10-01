/// lib/review/models/review_candidate.dart
///
/// Domain model for a DataFactory review candidate.
/// Schema version: 3.0 (DataFactory Quality Pass 2).
///
/// IMPORTANT: This model is READ-ONLY from the DataFactory perspective.
/// City Lab never modifies the source data; it only writes InboxDecision
/// records alongside it.
library;

/// Parsed from `assets/city_packs/<city>/review_candidates.json`.
class ReviewCandidate {
  // ── Identity ────────────────────────────────────────────────────────
  /// Stable canonical ID produced by DataFactory — use for stable matching.
  final String canonicalId;
  final String name;
  final String? nameEn;
  final String? nameHi;
  final List<String> alternateNames;
  final List<AlternateNameRecord> alternateNameRecords;

  // ── Geo ─────────────────────────────────────────────────────────────
  final double latitude;
  final double longitude;

  // ── Classification ───────────────────────────────────────────────────
  final String category;
  final String? subcategory;
  final List<CategoryVote> categoryVotes;
  final String tier;

  // ── Contact / business ───────────────────────────────────────────────
  final String? address;
  final String? website;
  final String? phone;
  final String? email;
  final String? openingHours;
  final String? openingHoursSource;

  // ── Enrichment ───────────────────────────────────────────────────────
  final String? wikidataId;
  final String? wikipediaUrl;
  final String? wikidataP18;
  final String? commonsImage;
  final String? commonsCategory;
  final String? prose;

  // ── Tags & raw OSM ──────────────────────────────────────────────────
  final List<String> tags;
  final Map<String, String> osmTags;

  // ── Provenance ──────────────────────────────────────────────────────
  final Map<String, List<String>> externalIds;
  final List<SourceProvenanceRecord> sourcesProvenance;
  final int sourceCount;

  // ── DataFactory decision ─────────────────────────────────────────────
  final double confidence;
  final String? relevanceStage1;
  final String? relevanceReason1;
  final ReviewPriority reviewPriority;
  final String suggestedAction;
  final String travelRelevanceDecision;
  final String travelRelevanceReason;
  final double travelRelevanceScore;
  final Map<String, dynamic> travelRelevanceEvidence;
  final List<String> missingFields;

  const ReviewCandidate({
    required this.canonicalId,
    required this.name,
    this.nameEn,
    this.nameHi,
    this.alternateNames = const [],
    this.alternateNameRecords = const [],
    required this.latitude,
    required this.longitude,
    required this.category,
    this.subcategory,
    this.categoryVotes = const [],
    required this.tier,
    this.address,
    this.website,
    this.phone,
    this.email,
    this.openingHours,
    this.openingHoursSource,
    this.wikidataId,
    this.wikipediaUrl,
    this.wikidataP18,
    this.commonsImage,
    this.commonsCategory,
    this.prose,
    this.tags = const [],
    this.osmTags = const {},
    this.externalIds = const {},
    this.sourcesProvenance = const [],
    this.sourceCount = 1,
    required this.confidence,
    this.relevanceStage1,
    this.relevanceReason1,
    required this.reviewPriority,
    required this.suggestedAction,
    required this.travelRelevanceDecision,
    required this.travelRelevanceReason,
    required this.travelRelevanceScore,
    this.travelRelevanceEvidence = const {},
    this.missingFields = const [],
  });

  bool get hasImage =>
      commonsImage != null ||
      wikidataP18 != null ||
      !missingFields.contains('primary_image');

  bool get hasDescription =>
      (prose != null && prose!.trim().isNotEmpty) ||
      !missingFields.contains('description');

  bool get hasOpeningHours =>
      (openingHours != null && openingHours!.trim().isNotEmpty) ||
      !missingFields.contains('opening_hours');

  bool get isCore => tier == 'core_destination';
  bool get isRecommended => tier == 'recommended';

  List<String> get sourceNames =>
      sourcesProvenance.map((s) => s.source).toSet().toList();

  factory ReviewCandidate.fromJson(Map<String, dynamic> json) {
    ReviewPriority priority;
    final priorityStr = (json['review_priority'] as String? ?? 'LOW').toUpperCase();
    switch (priorityStr) {
      case 'HIGH':
        priority = ReviewPriority.high;
        break;
      case 'MEDIUM':
        priority = ReviewPriority.medium;
        break;
      default:
        priority = ReviewPriority.low;
    }

    return ReviewCandidate(
      canonicalId: json['canonical_id'] as String? ??
          json['place_id'] as String? ??
          '${json['name']}_${json['latitude']}_${json['longitude']}',
      name: json['name'] as String? ?? 'Unknown',
      nameEn: json['name_en'] as String?,
      nameHi: json['name_hi'] as String?,
      alternateNames: (json['alternate_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      alternateNameRecords: (json['alternate_name_records'] as List<dynamic>?)
              ?.map((e) => AlternateNameRecord.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          const [],
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'unknown',
      subcategory: json['subcategory'] as String?,
      categoryVotes: (json['category_votes'] as List<dynamic>?)
              ?.map((e) =>
                  CategoryVote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tier: json['tier'] as String? ?? 'discovery',
      address: json['address'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      openingHours: json['opening_hours'] as String?,
      openingHoursSource: json['opening_hours_source'] as String?,
      wikidataId: json['wikidata_id'] as String?,
      wikipediaUrl: json['wikipedia_url'] as String?,
      wikidataP18: json['wikidata_p18'] as String?,
      commonsImage: json['commons_image'] as String?,
      commonsCategory: json['commons_category'] as String?,
      prose: json['prose'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      osmTags: (json['osm_tags'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
      externalIds: (json['external_ids'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List<dynamic>).map((e) => e.toString()).toList(),
            ),
          ) ??
          const {},
      sourcesProvenance:
          (json['sources_provenance'] as List<dynamic>?)
                  ?.map((e) => SourceProvenanceRecord.fromJson(
                      e as Map<String, dynamic>))
                  .toList() ??
              const [],
      sourceCount: (json['source_count'] as int?) ?? 1,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      relevanceStage1: json['relevance_stage1'] as String?,
      relevanceReason1: json['relevance_reason1'] as String?,
      reviewPriority: priority,
      suggestedAction:
          json['suggested_action'] as String? ?? 'REVIEW',
      travelRelevanceDecision:
          json['travel_relevance_decision'] as String? ?? 'REVIEW',
      travelRelevanceReason:
          json['travel_relevance_reason'] as String? ?? 'UNKNOWN',
      travelRelevanceScore:
          (json['travel_relevance_score'] as num?)?.toDouble() ?? 0.5,
      travelRelevanceEvidence:
          (json['travel_relevance_evidence'] as Map<String, dynamic>?) ??
              const {},
      missingFields: (json['missing_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

enum ReviewPriority { high, medium, low }

extension ReviewPriorityX on ReviewPriority {
  String get label {
    switch (this) {
      case ReviewPriority.high:
        return 'HIGH';
      case ReviewPriority.medium:
        return 'MEDIUM';
      case ReviewPriority.low:
        return 'LOW';
    }
  }

  int get sortOrder {
    switch (this) {
      case ReviewPriority.high:
        return 0;
      case ReviewPriority.medium:
        return 1;
      case ReviewPriority.low:
        return 2;
    }
  }
}

class AlternateNameRecord {
  final String name;
  final String source;
  final double confidence;
  final String? evidence;

  const AlternateNameRecord({
    required this.name,
    required this.source,
    required this.confidence,
    this.evidence,
  });

  factory AlternateNameRecord.fromJson(Map<String, dynamic> json) {
    return AlternateNameRecord(
      name: json['name'] as String? ?? '',
      source: json['source'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      evidence: json['evidence'] as String?,
    );
  }
}

class CategoryVote {
  final String category;
  final String? subcategory;
  final String source;
  final double weight;

  const CategoryVote({
    required this.category,
    this.subcategory,
    required this.source,
    required this.weight,
  });

  factory CategoryVote.fromJson(Map<String, dynamic> json) {
    return CategoryVote(
      category: json['category'] as String? ?? '',
      subcategory: json['subcategory'] as String?,
      source: json['source'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class SourceProvenanceRecord {
  final String source;
  final String? sourceId;

  const SourceProvenanceRecord({
    required this.source,
    this.sourceId,
  });

  factory SourceProvenanceRecord.fromJson(Map<String, dynamic> json) {
    return SourceProvenanceRecord(
      source: json['source'] as String? ?? '',
      sourceId: json['source_id'] as String?,
    );
  }
}
