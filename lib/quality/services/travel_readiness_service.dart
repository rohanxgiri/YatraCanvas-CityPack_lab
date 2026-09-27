import '../config/travel_readiness_weights.dart';
import '../models/quality_dimension.dart';
import '../models/travel_readiness_score.dart';
import '../../domain/city_pack.dart';

class TravelReadinessService {
  final TravelReadinessWeights weights;

  const TravelReadinessService({this.weights = TravelReadinessWeights.standard});

  TravelReadinessScore calculateScore({
    required CityPack pack,
    required Map<String, dynamic> dbStats,
  }) {
    final Map<String, QualityDimension> dimensions = {};
    final List<String> warnings = [];

    final totalPlaces = (dbStats['total_places'] as int?) ?? 0;
    if (totalPlaces == 0) {
      return const TravelReadinessScore(
        overallScore: 0,
        dimensions: {},
        warnings: ['Dataset contains zero places.'],
        summary: 'Cannot evaluate travel readiness on empty dataset.',
      );
    }

    // 1. Core Attraction Depth (weight 0.30)
    // Minimum 10 core tourist destinations needed for multi-day trips
    final coreTotal = (dbStats['core_total'] as int?) ?? 0;

    double coreDepthScore;
    DimensionStatus coreDepthStatus;
    String coreDepthReason;

    if (coreTotal == 0) {
      coreDepthScore = 0.0;
      coreDepthStatus = DimensionStatus.fail;
      coreDepthReason = 'Zero Core Destinations defined. YatraCanvas cannot build signature itineraries.';
      warnings.add('Zero Core Destinations defined.');
    } else if (coreTotal < 10) {
      coreDepthScore = (coreTotal / 10.0) * 0.6;
      coreDepthStatus = DimensionStatus.warning;
      coreDepthReason = 'Only $coreTotal Core Destinations available (minimum 10 recommended for multi-day plans).';
      warnings.add('Low Core Destination count ($coreTotal places).');
    } else {
      coreDepthScore = 1.0;
      coreDepthStatus = DimensionStatus.pass;
      coreDepthReason = '$coreTotal Core Destinations provide robust anchors for multi-day itineraries.';
    }

    dimensions['core_depth'] = QualityDimension(
      id: 'core_depth',
      label: 'Core Attraction Depth',
      score: coreDepthScore,
      weight: weights.coreAttractionDepth,
      status: coreDepthStatus,
      reason: coreDepthReason,
      affectedCount: coreTotal < 10 ? (10 - coreTotal) : 0,
    );

    // 2. Category Balance (weight 0.25)
    // Checks for healthy mix of attractions, dining, culture, outdoors
    // Detects datasets that are 95% restaurants/hotels with almost no tourist sights
    final categoryCounts = (dbStats['category_counts'] as Map<String, dynamic>?) ?? {};
    final diningCount = (categoryCounts['food_and_drink'] as int? ?? 0) +
        (categoryCounts['restaurant'] as int? ?? 0) +
        (categoryCounts['cafe'] as int? ?? 0);
    final hotelCount = (categoryCounts['hotel'] as int? ?? 0) +
        (categoryCounts['lodging'] as int? ?? 0);
    final culturalSightCount = (categoryCounts['attraction'] as int? ?? 0) +
        (categoryCounts['monument'] as int? ?? 0) +
        (categoryCounts['temple'] as int? ?? 0) +
        (categoryCounts['museum'] as int? ?? 0) +
        (categoryCounts['viewpoint'] as int? ?? 0) +
        (categoryCounts['park'] as int? ?? 0) +
        (categoryCounts['heritage'] as int? ?? 0);

    final totalIdentified = diningCount + hotelCount + culturalSightCount;
    double balanceScore;
    DimensionStatus balanceStatus;
    String balanceReason;

    if (culturalSightCount == 0 && totalPlaces > 0) {
      balanceScore = 0.15;
      balanceStatus = DimensionStatus.fail;
      balanceReason = 'Extreme imbalance: 0 tourist attractions or cultural sights found in dataset.';
      warnings.add('Dataset has 0 tourist sights. Itineraries cannot be built.');
    } else if (totalIdentified > 0 && (culturalSightCount / totalIdentified) < 0.05) {
      // Less than 5% cultural sights while dominating dining/hotel
      balanceScore = 0.35;
      balanceStatus = DimensionStatus.warning;
      balanceReason = 'Attraction coverage is sparse ($culturalSightCount sights vs ${diningCount + hotelCount} hospitality venues).';
      warnings.add('Category imbalance: hospitality venues dwarf tourist attractions ($culturalSightCount sights).');
    } else {
      final categoryDiversity = categoryCounts.keys.where((k) => (categoryCounts[k] as int? ?? 0) > 0).length;
      if (categoryDiversity >= 5) {
        balanceScore = 1.0;
        balanceStatus = DimensionStatus.pass;
        balanceReason = 'Healthy category balance with $culturalSightCount sights and $categoryDiversity active categories.';
      } else {
        balanceScore = 0.70;
        balanceStatus = DimensionStatus.warning;
        balanceReason = 'Limited category diversity ($categoryDiversity categories active).';
      }
    }

    dimensions['category_balance'] = QualityDimension(
      id: 'category_balance',
      label: 'Category Balance & Diversity',
      score: balanceScore,
      weight: weights.categoryBalance,
      status: balanceStatus,
      reason: balanceReason,
      affectedCount: culturalSightCount,
    );

    // 3. Hero Media Availability (weight 0.20)
    // Core destinations must have photos for consumer-facing itinerary cards
    final coreWithImg = (dbStats['core_with_images'] as int?) ?? 0;
    double heroMediaScore;
    DimensionStatus heroMediaStatus;
    String heroMediaReason;

    if (coreTotal == 0) {
      heroMediaScore = 0.0;
      heroMediaStatus = DimensionStatus.fail;
      heroMediaReason = 'No Core Destinations to assess hero media.';
    } else {
      final coreImgRatio = coreWithImg / coreTotal;
      heroMediaScore = coreImgRatio;
      if (coreImgRatio >= 0.80) {
        heroMediaStatus = DimensionStatus.pass;
        heroMediaReason = '${(coreImgRatio * 100).round()}% of Core Destinations have verified photos ($coreWithImg / $coreTotal).';
      } else if (coreImgRatio >= 0.40) {
        heroMediaStatus = DimensionStatus.warning;
        final missing = coreTotal - coreWithImg;
        heroMediaReason = '$missing Core Destinations lack photos (${(coreImgRatio * 100).round()}% coverage).';
        warnings.add('$missing Core Destinations missing photos.');
      } else {
        heroMediaStatus = DimensionStatus.fail;
        final missing = coreTotal - coreWithImg;
        heroMediaReason = 'Critical image shortage: $missing of $coreTotal Core Destinations lack photos.';
        warnings.add('Severe lack of Core POI photos ($coreWithImg / $coreTotal).');
      }
    }

    dimensions['hero_media'] = QualityDimension(
      id: 'hero_media',
      label: 'Hero Media Availability',
      score: heroMediaScore,
      weight: weights.heroMediaAvailability,
      status: heroMediaStatus,
      reason: heroMediaReason,
      affectedCount: coreTotal - coreWithImg,
    );

    // 4. Operating Schedule Coverage (weight 0.15)
    // Opening hours are essential for time-slotted itinerary planning
    final coreWithHours = (dbStats['core_with_hours'] as int?) ?? 0;
    double scheduleScore;
    DimensionStatus scheduleStatus;
    String scheduleReason;

    if (coreTotal == 0) {
      scheduleScore = 0.0;
      scheduleStatus = DimensionStatus.fail;
      scheduleReason = 'No Core Destinations to evaluate schedule coverage.';
    } else {
      final hoursRatio = coreWithHours / coreTotal;
      scheduleScore = hoursRatio;
      if (hoursRatio >= 0.70) {
        scheduleStatus = DimensionStatus.pass;
        scheduleReason = '${(hoursRatio * 100).round()}% Core Destinations have operating hours ($coreWithHours / $coreTotal).';
      } else if (hoursRatio >= 0.40) {
        scheduleStatus = DimensionStatus.warning;
        final missing = coreTotal - coreWithHours;
        scheduleReason = '$missing Core Destinations missing opening hours (${(hoursRatio * 100).round()}% coverage).';
        warnings.add('$missing Core Destinations lack opening hours.');
      } else {
        scheduleStatus = DimensionStatus.fail;
        final missing = coreTotal - coreWithHours;
        scheduleReason = 'Severe schedule gap: $missing of $coreTotal Core Destinations have unknown operating hours.';
        warnings.add('Critical schedule gap for Core POIs ($coreWithHours / $coreTotal).');
      }
    }

    dimensions['schedule_coverage'] = QualityDimension(
      id: 'schedule_coverage',
      label: 'Operating Schedule Coverage',
      score: scheduleScore,
      weight: weights.operatingScheduleCoverage,
      status: scheduleStatus,
      reason: scheduleReason,
      affectedCount: coreTotal - coreWithHours,
    );

    // 5. Visit Duration Usability (weight 0.10)
    // Verified places with categories that have duration priors
    final verifiedCategories = (dbStats['places_with_valid_category'] as int?) ?? totalPlaces;
    final double categoryValidityRatio = (verifiedCategories / totalPlaces).clamp(0.0, 1.0);
    final durationScore = categoryValidityRatio;
    final durStatus = categoryValidityRatio >= 0.90 ? DimensionStatus.pass : DimensionStatus.warning;
    final durReason = '${(categoryValidityRatio * 100).round()}% of places have standardized travel categories suitable for duration estimation.';

    dimensions['visit_duration'] = QualityDimension(
      id: 'visit_duration',
      label: 'Visit Duration Usability',
      score: durationScore,
      weight: weights.visitDurationUsability,
      status: durStatus,
      reason: durReason,
      affectedCount: totalPlaces - verifiedCategories,
    );

    // Compute weighted aggregate
    double weightedSum = 0.0;
    for (final dim in dimensions.values) {
      weightedSum += (dim.score ?? 0.0) * dim.weight;
    }

    final double normalized = weightedSum / weights.totalWeight;
    final int overallScore = (normalized * 100).round().clamp(0, 100);

    return TravelReadinessScore(
      overallScore: overallScore,
      dimensions: dimensions,
      warnings: warnings,
      summary: 'Travel Readiness score: $overallScore/100 across ${dimensions.length} itinerary dimensions.',
    );
  }
}
