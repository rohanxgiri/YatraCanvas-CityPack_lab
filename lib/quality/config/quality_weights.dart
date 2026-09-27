/// QualityWeights defines centralized, configurable weightings
/// for the YatraCanvas City Pack Data Quality Score.
class QualityWeights {
  final double coreQuality;
  final double geoIntegrity;
  final double metadataCompleteness;
  final double categoryQuality;
  final double uniqueness;
  final double provenance;
  final double freshness;
  final double manualQa;

  const QualityWeights({
    this.coreQuality = 0.25,
    this.geoIntegrity = 0.20,
    this.metadataCompleteness = 0.15,
    this.categoryQuality = 0.10,
    this.uniqueness = 0.10,
    this.provenance = 0.10,
    this.freshness = 0.05,
    this.manualQa = 0.05,
  });

  static const QualityWeights standard = QualityWeights();

  /// Total sum of all configured dimension weights
  double get totalWeight =>
      coreQuality +
      geoIntegrity +
      metadataCompleteness +
      categoryQuality +
      uniqueness +
      provenance +
      freshness +
      manualQa;
}
