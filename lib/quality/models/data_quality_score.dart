import 'quality_dimension.dart';

class DataQualityScore {
  final int overallScore; // 0 to 100
  final Map<String, QualityDimension> dimensions;
  final String summary;

  const DataQualityScore({
    required this.overallScore,
    required this.dimensions,
    required this.summary,
  });

  QualityDimension? getDimension(String id) => dimensions[id];

  Map<String, dynamic> toJson() => {
        'overall_score': overallScore,
        'summary': summary,
        'dimensions': dimensions.map((k, v) => MapEntry(k, v.toJson())),
      };
}
