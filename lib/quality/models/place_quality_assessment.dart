enum PlaceReviewStatus {
  ready,
  needsReview,
  excluded,
}

class PlaceQualityAssessment {
  final String placeId;
  final int qualityScore; // 0 to 100
  final int identityScore;
  final int locationScore;
  final int categoryScore;
  final int completenessScore;
  final int provenanceScore;
  final PlaceReviewStatus status;
  final List<String> flags;
  final List<String> issues;

  const PlaceQualityAssessment({
    required this.placeId,
    required this.qualityScore,
    required this.identityScore,
    required this.locationScore,
    required this.categoryScore,
    required this.completenessScore,
    required this.provenanceScore,
    required this.status,
    this.flags = const [],
    this.issues = const [],
  });

  Map<String, dynamic> toJson() => {
        'place_id': placeId,
        'quality_score': qualityScore,
        'components': {
          'identity': identityScore,
          'location': locationScore,
          'category': categoryScore,
          'completeness': completenessScore,
          'provenance': provenanceScore,
        },
        'status': status.name,
        'flags': flags,
        'issues': issues,
      };
}
