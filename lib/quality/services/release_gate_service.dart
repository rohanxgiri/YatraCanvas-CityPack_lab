import '../config/release_gate_config.dart';
import '../models/data_quality_score.dart';
import '../models/manual_qa_summary.dart';
import '../models/release_gate_result.dart';
import '../models/travel_readiness_score.dart';
import '../../domain/city_pack.dart';

class ReleaseGateService {
  final ReleaseGateConfig config;

  const ReleaseGateService({this.config = ReleaseGateConfig.standard});

  ReleaseGateResult evaluate({
    required CityPack pack,
    required Map<String, dynamic> dbStats,
    required DataQualityScore dataQuality,
    required TravelReadinessScore travelReadiness,
    required ManualQaSummary manualQa,
  }) {
    final List<String> criticalBlockers = [];
    final List<String> warnings = [];
    final Map<String, bool> checks = {};

    // 1. Schema Validation Gate
    final bool schemaValid = (pack.manifest.containsKey('city') ||
            pack.manifest.containsKey('city_id') ||
            pack.manifest.containsKey('city_name')) &&
        (pack.manifest.containsKey('pack_version') ||
            pack.manifest.containsKey('city_pack_version') ||
            pack.manifest.containsKey('schema_version')) &&
        pack.manifest.containsKey('counts');
    checks['schema_valid'] = schemaValid;
    if (!schemaValid && config.requireSchemaValid) {
      criticalBlockers.add('Corrupt or incomplete manifest schema.');
    }

    // 2. Core POI Geographic Validation Gate (Critical)
    // Non-negotiable rule 0.2: A weighted score must NEVER override a critical failure!
    final coreOutsideBounds = (dbStats['core_outside_bounds'] as int?) ?? 0;
    final bool coreGeoPassed = coreOutsideBounds == 0;
    checks['core_geo_integrity'] = coreGeoPassed;
    if (!coreGeoPassed && config.requireNoCoreGeoFailures) {
      criticalBlockers.add('$coreOutsideBounds Core Destination(s) failed geographic boundary validation.');
    }

    // 3. Manual QA Sample Gate
    // Non-negotiable rule 0.1: Never assume missing info is good info.
    // Minimum sample required before release can be approved.
    bool manualQaPassed = false;
    if (manualQa.state == ManualQaState.sufficientSample) {
      if (manualQa.defectRate <= config.maxManualDefectRate) {
        manualQaPassed = true;
      } else {
        criticalBlockers.add('Manual QA defect rate of ${(manualQa.defectRate * 100).round()}% exceeds ${(config.maxManualDefectRate * 100).round()}% limit.');
      }
    } else if (manualQa.state == ManualQaState.notStarted) {
      criticalBlockers.add('Manual QA not started (0 of ${config.minimumManualQaSample} minimum sample completed).');
    } else {
      criticalBlockers.add('Manual QA sample insufficient (${manualQa.reviewedCount} of ${config.minimumManualQaSample} reviewed).');
    }
    checks['manual_qa_sufficient'] = manualQaPassed;

    // 4. Core Destination Count & Image Coverage Gate
    final coreTotal = (dbStats['core_total'] as int?) ?? 0;
    final coreWithImg = (dbStats['core_with_images'] as int?) ?? 0;
    final coreImgRatio = coreTotal > 0 ? (coreWithImg / coreTotal) : 0.0;
    final bool coreImgPassed = coreImgRatio >= config.minCoreImageCoverage;
    checks['core_image_coverage'] = coreImgPassed;
    if (!coreImgPassed) {
      final missing = coreTotal - coreWithImg;
      warnings.add('Core photo coverage is ${(coreImgRatio * 100).round()}% (below ${(config.minCoreImageCoverage * 100).round()}% threshold; $missing Core POIs lack images).');
    }

    // 5. Itinerary Sights Minimum Gate
    final categoryCounts = (dbStats['category_counts'] as Map<String, dynamic>?) ?? {};
    final culturalSightCount = (categoryCounts['attraction'] as int? ?? 0) +
        (categoryCounts['monument'] as int? ?? 0) +
        (categoryCounts['temple'] as int? ?? 0) +
        (categoryCounts['museum'] as int? ?? 0) +
        (categoryCounts['viewpoint'] as int? ?? 0) +
        (categoryCounts['park'] as int? ?? 0);
    final bool attractionsPassed = culturalSightCount >= config.minAttractionsCount;
    checks['sufficient_attractions'] = attractionsPassed;
    if (!attractionsPassed) {
      criticalBlockers.add('Only $culturalSightCount tourist sights found (minimum ${config.minAttractionsCount} required to build itineraries).');
    }

    // 6. Aggregate Score Thresholds
    final bool dataQualityPassed = dataQuality.overallScore >= config.minDataQualityScore;
    checks['data_quality_threshold'] = dataQualityPassed;
    if (!dataQualityPassed) {
      criticalBlockers.add('Data Quality score (${dataQuality.overallScore}/100) below minimum ${config.minDataQualityScore.round()}.');
    }

    final bool travelReadinessPassed = travelReadiness.overallScore >= config.minTravelReadinessScore;
    checks['travel_readiness_threshold'] = travelReadinessPassed;
    if (!travelReadinessPassed) {
      warnings.add('Travel Readiness score (${travelReadiness.overallScore}/100) below recommended ${config.minTravelReadinessScore.round()}.');
    }

    // 7. General Warnings from DB Stats
    final outsideBoundsCount = (dbStats['places_outside_bounds'] as int?) ?? 0;
    if (outsideBoundsCount > 0 && coreGeoPassed) {
      warnings.add('$outsideBoundsCount non-core places are located outside city bounds.');
    }

    final sharedCoords = (dbStats['shared_coords_places_count'] as int?) ?? 0;
    if (sharedCoords > 0) {
      warnings.add('$sharedCoords places share duplicate coordinates with other entries.');
    }

    for (final trWarning in travelReadiness.warnings) {
      if (!warnings.contains(trWarning) && !criticalBlockers.contains(trWarning)) {
        warnings.add(trWarning);
      }
    }

    // Determine final Release Status
    ReleaseStatus status;
    if (criticalBlockers.isNotEmpty) {
      status = ReleaseStatus.blocked;
    } else if (!travelReadinessPassed || warnings.length >= 10) {
      status = ReleaseStatus.reviewRequired;
    } else {
      status = ReleaseStatus.ready;
    }

    return ReleaseGateResult(
      status: status,
      criticalBlockers: criticalBlockers,
      warnings: warnings,
      checks: checks,
      timestamp: DateTime.now().toIso8601String(),
    );
  }
}
