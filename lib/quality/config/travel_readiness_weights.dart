/// TravelReadinessWeights defines centralized weights for evaluating whether
/// a City Pack contains a viable, well-balanced distribution of places
/// suitable for generating multi-day tourist itineraries in YatraCanvas.
class TravelReadinessWeights {
  final double coreAttractionDepth;
  final double categoryBalance;
  final double heroMediaAvailability;
  final double operatingScheduleCoverage;
  final double visitDurationUsability;

  const TravelReadinessWeights({
    this.coreAttractionDepth = 0.30,
    this.categoryBalance = 0.25,
    this.heroMediaAvailability = 0.20,
    this.operatingScheduleCoverage = 0.15,
    this.visitDurationUsability = 0.10,
  });

  static const TravelReadinessWeights standard = TravelReadinessWeights();

  double get totalWeight =>
      coreAttractionDepth +
      categoryBalance +
      heroMediaAvailability +
      operatingScheduleCoverage +
      visitDurationUsability;
}
