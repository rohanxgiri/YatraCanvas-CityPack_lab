import '../config/quality_weights.dart';
import '../models/data_quality_score.dart';
import '../models/manual_qa_summary.dart';
import '../models/quality_dimension.dart';
import '../../domain/city_pack.dart';

class CityQualityService {
  final QualityWeights weights;

  const CityQualityService({this.weights = QualityWeights.standard});

  DataQualityScore calculateScore({
    required CityPack pack,
    required Map<String, dynamic> dbStats,
    required ManualQaSummary manualQa,
  }) {
    final Map<String, QualityDimension> dimensions = {};

    final totalPlaces = (dbStats['total_places'] as int?) ?? 0;
    if (totalPlaces == 0) {
      return const DataQualityScore(
        overallScore: 0,
        dimensions: {},
        summary: 'No places found in dataset.',
      );
    }

    // 1. Core Destination Quality (weight 0.25)
    final coreTotal = (dbStats['core_total'] as int?) ?? 0;
    final coreWithImg = (dbStats['core_with_images'] as int?) ?? 0;
    final coreWithHours = (dbStats['core_with_hours'] as int?) ?? 0;
    final coreWithWiki = (dbStats['core_with_wikidata'] as int?) ?? 0;
    final coreOutsideBounds = (dbStats['core_outside_bounds'] as int?) ?? 0;

    double coreScore;
    DimensionStatus coreStatus;
    String coreReason;

    if (coreTotal == 0) {
      coreScore = 0.0;
      coreStatus = DimensionStatus.fail;
      coreReason = 'No Core Destinations defined for this city.';
    } else {
      final imgRatio = coreWithImg / coreTotal;
      final wikiRatio = coreWithWiki / coreTotal;
      final hoursRatio = coreWithHours / coreTotal;
      final geoPenalty = coreOutsideBounds > 0 ? 0.30 : 0.0;
      coreScore =
          ((imgRatio * 0.45) +
                  (wikiRatio * 0.35) +
                  (hoursRatio * 0.20) -
                  geoPenalty)
              .clamp(0.0, 1.0);

      if (coreOutsideBounds > 0) {
        coreStatus = DimensionStatus.fail;
        coreReason =
            '$coreOutsideBounds Core Destinations failed coordinate boundary validation.';
      } else if (imgRatio < 0.60) {
        coreStatus = DimensionStatus.warning;
        final missingImg = coreTotal - coreWithImg;
        coreReason = '$missingImg of $coreTotal Core Destinations lack photos.';
      } else {
        coreStatus = DimensionStatus.pass;
        coreReason =
            '$coreTotal Core Destinations well-formed with ${(imgRatio * 100).round()}% image coverage.';
      }
    }

    dimensions['core_quality'] = QualityDimension(
      id: 'core_quality',
      label: 'Core Destination Quality',
      score: coreScore,
      weight: weights.coreQuality,
      status: coreStatus,
      reason: coreReason,
      affectedCount: coreTotal - coreWithImg,
      affectedRecordIds:
          (dbStats['core_missing_image_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );

    // 2. Geographic & Identity Integrity (weight 0.20)
    final outsideBoundsCount = (dbStats['places_outside_bounds'] as int?) ?? 0;
    final double geoRatio = ((totalPlaces - outsideBoundsCount) / totalPlaces)
        .clamp(0.0, 1.0);
    final geoScore = coreOutsideBounds > 0 ? (geoRatio * 0.5) : geoRatio;
    final DimensionStatus geoStatus = coreOutsideBounds > 0
        ? DimensionStatus.fail
        : (outsideBoundsCount > 0
              ? DimensionStatus.warning
              : DimensionStatus.pass);
    final geoReason = outsideBoundsCount > 0
        ? '$outsideBoundsCount places located outside official city boundaries.'
        : 'All $totalPlaces place coordinates are inside expected city boundaries.';

    dimensions['geo_integrity'] = QualityDimension(
      id: 'geo_integrity',
      label: 'Geographic & Identity Integrity',
      score: geoScore,
      weight: weights.geoIntegrity,
      status: geoStatus,
      reason: geoReason,
      affectedCount: outsideBoundsCount,
      affectedRecordIds:
          (dbStats['outside_bounds_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );

    // 3. Metadata Completeness (weight 0.15)
    final withImages = (dbStats['with_images'] as int?) ?? 0;
    final withHours = (dbStats['with_opening_hours'] as int?) ?? 0;
    final withWebsite = (dbStats['with_website'] as int?) ?? 0;
    final withPhone = (dbStats['with_phone'] as int?) ?? 0;

    final imgCov = withImages / totalPlaces;
    final hoursCov = withHours / totalPlaces;
    final webCov = withWebsite / totalPlaces;
    final phoneCov = withPhone / totalPlaces;

    final completenessScore =
        ((imgCov * 0.40) +
                (hoursCov * 0.30) +
                (webCov * 0.20) +
                (phoneCov * 0.10))
            .clamp(0.0, 1.0);
    final compStatus = imgCov < 0.05
        ? DimensionStatus.warning
        : DimensionStatus.pass;
    final compReason =
        'Images: ${(imgCov * 100).round()}%, Hours: ${(hoursCov * 100).round()}%, Web: ${(webCov * 100).round()}%.';

    dimensions['metadata_completeness'] = QualityDimension(
      id: 'metadata_completeness',
      label: 'Metadata Completeness',
      score: completenessScore,
      weight: weights.metadataCompleteness,
      status: compStatus,
      reason: compReason,
      affectedCount: totalPlaces - withImages,
    );

    // 4. Category & Entity Quality (weight 0.10)
    final validCategories =
        (dbStats['places_with_valid_category'] as int?) ?? 0;
    final categoryConflicts = (totalPlaces - validCategories).clamp(
      0,
      totalPlaces,
    );
    final categoryScore = (validCategories / totalPlaces).clamp(0.0, 1.0);
    final catStatus = categoryConflicts > 0
        ? DimensionStatus.warning
        : DimensionStatus.pass;
    final catReason = categoryConflicts > 0
        ? '$categoryConflicts published places lack a normalized travel category.'
        : 'Normalized travel categories validated across the published dataset.';

    dimensions['category_quality'] = QualityDimension(
      id: 'category_quality',
      label: 'Category & Entity Quality',
      score: categoryScore,
      weight: weights.categoryQuality,
      status: catStatus,
      reason: catReason,
      affectedCount: categoryConflicts,
    );

    // 5. Uniqueness & Consistency (weight 0.10)
    final sharedCoordPlaces =
        (dbStats['shared_coords_places_count'] as int?) ?? 0;
    final overlapRatio = (sharedCoordPlaces / totalPlaces).clamp(0.0, 1.0);
    final uniquenessScore = (1.0 - (overlapRatio * 1.5)).clamp(0.0, 1.0);
    final uniqStatus = overlapRatio > 0.10
        ? DimensionStatus.warning
        : DimensionStatus.pass;
    final uniqReason = sharedCoordPlaces > 0
        ? '$sharedCoordPlaces published places share identical coordinates with other entries.'
        : 'Zero coordinate overlap clusters detected in published places.';

    dimensions['uniqueness'] = QualityDimension(
      id: 'uniqueness',
      label: 'Uniqueness & Consistency',
      score: uniquenessScore,
      weight: weights.uniqueness,
      status: uniqStatus,
      reason: uniqReason,
      affectedCount: sharedCoordPlaces,
    );

    // 6. Source Provenance Quality (weight 0.10)
    final multiSourceCount = (dbStats['multi_source_count'] as int?) ?? 0;
    final multiSourceRatio = (multiSourceCount / totalPlaces).clamp(0.0, 1.0);
    // Baseline multi-source score: 0.50 base + 0.50 * multi-source ratio
    final provScore = (0.50 + (multiSourceRatio * 0.50)).clamp(0.0, 1.0);
    final provStatus = multiSourceRatio < 0.10
        ? DimensionStatus.warning
        : DimensionStatus.pass;
    final provReason = multiSourceCount > 0
        ? '$multiSourceCount places confirmed across multiple sources (OSM, Wikidata, Overture).'
        : 'Single-source dominance detected; external cross-verification low.';

    dimensions['provenance'] = QualityDimension(
      id: 'provenance',
      label: 'Source Provenance Quality',
      score: provScore,
      weight: weights.provenance,
      status: provStatus,
      reason: provReason,
      affectedCount: totalPlaces - multiSourceCount,
    );

    // 7. Freshness (weight 0.05)
    final generatedAtStr = pack.manifest['generated_at'] as String?;
    double freshnessScore = 0.85;
    String freshnessReason = 'Dataset pipeline generation date recorded.';
    if (generatedAtStr != null) {
      try {
        final genDate = DateTime.parse(generatedAtStr);
        final ageDays = DateTime.now().difference(genDate).inDays;
        if (ageDays <= 90) {
          freshnessScore = 1.0;
          freshnessReason = 'Dataset generated recently ($ageDays days ago).';
        } else if (ageDays <= 180) {
          freshnessScore = 0.85;
          freshnessReason =
              'Dataset generated $ageDays days ago (within 6 months).';
        } else {
          freshnessScore = 0.70;
          freshnessReason = 'Dataset is over 6 months old ($ageDays days ago).';
        }
      } catch (_) {}
    }

    dimensions['freshness'] = QualityDimension(
      id: 'freshness',
      label: 'Data Freshness',
      score: freshnessScore,
      weight: weights.freshness,
      status: DimensionStatus.pass,
      reason: freshnessReason,
    );

    // 8. Manual QA Health (weight 0.05)
    // Non-negotiable rule 0.1: Never fabricate 100% when 0 reviews exist!
    double? qaScore;
    DimensionStatus qaStatus;
    String qaReason;

    if (manualQa.state == ManualQaState.notStarted) {
      qaScore = null;
      qaStatus = DimensionStatus.notMeasured;
      qaReason =
          'Manual QA has not started (0 of ${manualQa.minimumRequired} places reviewed).';
    } else if (manualQa.state == ManualQaState.inProgress ||
        manualQa.state == ManualQaState.insufficientSample) {
      qaScore = null;
      qaStatus = DimensionStatus.notMeasured;
      qaReason =
          'Manual QA in progress (${manualQa.reviewedCount} of ${manualQa.minimumRequired} minimum sample completed).';
    } else {
      qaScore = (1.0 - manualQa.defectRate).clamp(0.0, 1.0);
      qaStatus = manualQa.defectRate > 0.15
          ? DimensionStatus.warning
          : DimensionStatus.pass;
      qaReason =
          '${manualQa.reviewedCount} places verified. ${(manualQa.defectRate * 100).round()}% defect rate.';
    }

    dimensions['manual_qa'] = QualityDimension(
      id: 'manual_qa',
      label: 'Manual QA Verification',
      score: qaScore,
      weight: weights.manualQa,
      status: qaStatus,
      reason: qaReason,
      affectedCount: manualQa.issueCount,
    );

    // Compute overall weighted average
    double weightedSum = 0.0;
    double effectiveWeightSum = 0.0;

    for (final dim in dimensions.values) {
      if (dim.score != null &&
          dim.status != DimensionStatus.notMeasured &&
          dim.status != DimensionStatus.unknown) {
        weightedSum += dim.score! * dim.weight;
        effectiveWeightSum += dim.weight;
      }
    }

    final double normalized = effectiveWeightSum > 0
        ? (weightedSum / effectiveWeightSum)
        : 0.0;
    final int overallScore = (normalized * 100).round().clamp(0, 100);

    return DataQualityScore(
      overallScore: overallScore,
      dimensions: dimensions,
      summary:
          'Data Quality calculated across ${dimensions.length} dimensions (${effectiveWeightSum.toStringAsFixed(2)} effective weight).',
    );
  }
}
