import 'quality_dimension.dart';

class TravelReadinessScore {
  final int overallScore; // 0 to 100
  final Map<String, QualityDimension> dimensions;
  final List<String> warnings;
  final String summary;

  const TravelReadinessScore({
    required this.overallScore,
    required this.dimensions,
    required this.warnings,
    required this.summary,
  });

  QualityDimension? getDimension(String id) => dimensions[id];

  Map<String, dynamic> toJson() => {
        'overall_score': overallScore,
        'summary': summary,
        'warnings': warnings,
        'dimensions': dimensions.map((k, v) => MapEntry(k, v.toJson())),
      };
}
