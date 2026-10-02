/// ReleaseGateConfig defines the explicit rules and thresholds
/// required for a City Pack to achieve READY status for production YatraCanvas.
class ReleaseGateConfig {
  final bool requireSchemaValid;
  final bool requireNoCoreGeoFailures;
  final int minimumManualQaSample;
  final double minCoreImageCoverage;
  final int minAttractionsCount;
  final double minDataQualityScore;
  final double minTravelReadinessScore;
  final double maxAllowedQuarantinedRatio;
  final double maxManualDefectRate;

  const ReleaseGateConfig({
    this.requireSchemaValid = true,
    this.requireNoCoreGeoFailures = true,
    this.minimumManualQaSample = 50,
    this.minCoreImageCoverage = 0.50,
    this.minAttractionsCount = 10,
    this.minDataQualityScore = 70.0,
    this.minTravelReadinessScore = 60.0,
    this.maxAllowedQuarantinedRatio = 0.60,
    this.maxManualDefectRate = 0.10,
  });

  static const ReleaseGateConfig standard = ReleaseGateConfig();
}
