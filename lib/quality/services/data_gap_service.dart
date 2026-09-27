import '../models/data_gap_item.dart';
import '../../domain/city_pack.dart';

class DataGapService {
  const DataGapService();

  List<DataGapItem> analyzeGaps({
    required CityPack pack,
    required Map<String, dynamic> dbStats,
  }) {
    final List<DataGapItem> gaps = [];

    final totalPlaces = (dbStats['total_places'] as int?) ?? 0;
    if (totalPlaces == 0) return gaps;

    // 1. Core Destinations without Images
    final coreTotal = (dbStats['core_total'] as int?) ?? 0;
    final coreWithImg = (dbStats['core_with_images'] as int?) ?? 0;
    final coreMissingImgCount = coreTotal - coreWithImg;
    final coreMissingImgIds = (dbStats['core_missing_image_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (coreMissingImgCount > 0) {
      gaps.add(DataGapItem(
        id: 'core_missing_images',
        title: 'Core Destinations Missing Photos',
        count: coreMissingImgCount,
        severity: coreMissingImgCount > (coreTotal * 0.3)
            ? GapSeverity.critical
            : GapSeverity.warning,
        reason: '$coreMissingImgCount of $coreTotal flagship tourist destinations have no hero photo.',
        affectedPlaceIds: coreMissingImgIds,
        filterPreset: 'core_missing_images',
      ));
    }

    // 2. Core Destinations without Opening Hours
    final coreWithHours = (dbStats['core_with_hours'] as int?) ?? 0;
    final coreMissingHoursCount = coreTotal - coreWithHours;
    final coreMissingHoursIds = (dbStats['core_missing_hours_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (coreMissingHoursCount > 0) {
      gaps.add(DataGapItem(
        id: 'core_missing_hours',
        title: 'Core Destinations Missing Opening Hours',
        count: coreMissingHoursCount,
        severity: coreMissingHoursCount > (coreTotal * 0.4)
            ? GapSeverity.critical
            : GapSeverity.warning,
        reason: '$coreMissingHoursCount of $coreTotal flagship destinations lack operating schedule for itinerary time-slots.',
        affectedPlaceIds: coreMissingHoursIds,
        filterPreset: 'core_missing_hours',
      ));
    }

    // 3. Core Destinations Failing Geographic Validation
    final coreOutsideBounds = (dbStats['core_outside_bounds'] as int?) ?? 0;
    final coreOutsideIds = (dbStats['core_outside_bounds_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (coreOutsideBounds > 0) {
      gaps.add(DataGapItem(
        id: 'core_geo_outliers',
        title: 'Core Destinations Outside City Bounds',
        count: coreOutsideBounds,
        severity: GapSeverity.critical,
        reason: '$coreOutsideBounds flagship destination(s) plotted outside official city bounding box.',
        affectedPlaceIds: coreOutsideIds,
        filterPreset: 'core_geo_issue',
      ));
    }

    // 4. All Places Outside Bounding Box
    final outsideBoundsCount = (dbStats['places_outside_bounds'] as int?) ?? 0;
    final outsideIds = (dbStats['outside_bounds_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (outsideBoundsCount > 0) {
      gaps.add(DataGapItem(
        id: 'places_outside_bounds',
        title: 'Places Outside Expected Service Area',
        count: outsideBoundsCount,
        severity: GapSeverity.warning,
        reason: '$outsideBoundsCount places plotted outside administrative boundary envelope.',
        affectedPlaceIds: outsideIds,
        filterPreset: 'geo_outliers',
      ));
    }

    // 5. Duplicate Coordinate Clusters
    final sharedCoordPlaces = (dbStats['shared_coords_places_count'] as int?) ?? 0;
    final sharedCoordIds = (dbStats['shared_coords_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (sharedCoordPlaces > 0) {
      gaps.add(DataGapItem(
        id: 'duplicate_coordinates',
        title: 'Duplicate Coordinate Overlap Clusters',
        count: sharedCoordPlaces,
        severity: GapSeverity.warning,
        reason: '$sharedCoordPlaces places share identical latitude/longitude with other POIs.',
        affectedPlaceIds: sharedCoordIds,
        filterPreset: 'duplicate_coords',
      ));
    }

    // 6. Single-Source Provenance Vulnerability
    final multiSourceCount = (dbStats['multi_source_count'] as int?) ?? 0;
    final singleSourceCount = totalPlaces - multiSourceCount;
    if (singleSourceCount > 0) {
      gaps.add(DataGapItem(
        id: 'single_source_provenance',
        title: 'Single-Source Places (Unverified)',
        count: singleSourceCount,
        severity: GapSeverity.info,
        reason: '$singleSourceCount places originate from a single upstream provider without cross-validation.',
        filterPreset: 'single_source',
      ));
    }

    // 7. General Missing Images
    final withImages = (dbStats['with_images'] as int?) ?? 0;
    final missingImagesTotal = totalPlaces - withImages;
    if (missingImagesTotal > 0) {
      gaps.add(DataGapItem(
        id: 'all_missing_images',
        title: 'All Places Missing Photos',
        count: missingImagesTotal,
        severity: GapSeverity.info,
        reason: '$missingImagesTotal of $totalPlaces places have no associated photos.',
        filterPreset: 'missing_images',
      ));
    }

    // 8. General Missing Hours
    final withHours = (dbStats['with_opening_hours'] as int?) ?? 0;
    final missingHoursTotal = totalPlaces - withHours;
    if (missingHoursTotal > 0) {
      gaps.add(DataGapItem(
        id: 'all_missing_hours',
        title: 'All Places Missing Operating Hours',
        count: missingHoursTotal,
        severity: GapSeverity.info,
        reason: '$missingHoursTotal of $totalPlaces places have no opening hours schedule.',
        filterPreset: 'missing_hours',
      ));
    }

    return gaps;
  }
}
