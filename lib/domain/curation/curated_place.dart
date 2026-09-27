import '../lab_place.dart';
import 'place_addition.dart';
import 'place_exclusion.dart';
import 'place_override.dart';

enum FieldOrigin {
  humanOverride,
  trustedProvider,
  normalizedFallback,
  manualAddition,
  unknown,
}

class FieldProvenanceInfo {
  final String fieldName;
  final dynamic currentValue;
  final dynamic previousValue;
  final FieldOrigin origin;
  final String sourceLabel;
  final String? verifiedDate;

  const FieldProvenanceInfo({
    required this.fieldName,
    required this.currentValue,
    this.previousValue,
    required this.origin,
    required this.sourceLabel,
    this.verifiedDate,
  });

  bool get isManuallyVerified => origin == FieldOrigin.humanOverride || origin == FieldOrigin.manualAddition;
}

/// Represents the resolved composite place:
/// CuratedPlace = Generated Place + Human Overrides + Manual Additions - Manual Exclusions
class CuratedPlace {
  final LabPlace? rawPlace;
  final PlaceOverride? override;
  final PlaceAddition? addition;
  final PlaceExclusion? exclusion;

  const CuratedPlace({
    this.rawPlace,
    this.override,
    this.addition,
    this.exclusion,
  }) : assert(rawPlace != null || addition != null, 'Must provide either rawPlace or addition');

  String get id => addition?.id ?? rawPlace!.id;
  String get cityId => addition?.cityId ?? rawPlace!.cityId;

  bool get isExcluded => exclusion != null;
  bool get isManuallyAdded => addition != null;
  bool get isManuallyEdited => override != null && override!.hasChanges;

  // Effective Field Resolution:
  // 1. Verified Human Override
  // 2. Manual Addition
  // 3. Best trusted provider value (rawPlace)
  // 4. Fallback / Unknown

  String get name => override?.name ?? addition?.name ?? rawPlace?.name ?? 'Unknown';
  String? get nameHi => override?.nameHi ?? addition?.nameHi ?? rawPlace?.nameHi;

  double get latitude => override?.latitude ?? addition?.latitude ?? rawPlace?.latitude ?? 0.0;
  double get longitude => override?.longitude ?? addition?.longitude ?? rawPlace?.longitude ?? 0.0;

  String? get address => override?.address ?? addition?.address ?? rawPlace?.address;

  String get category => override?.category ?? addition?.category ?? rawPlace?.category ?? 'other';
  String? get subcategory => override?.subcategory ?? addition?.subcategory ?? rawPlace?.subcategory;

  String get tier {
    if (override?.tier != null) return override!.tier!;
    if (override?.isCore == true) return 'core_destination';
    if (override?.isCore == false && rawPlace?.tier == 'core_destination') return 'recommended';
    return addition?.tier ?? rawPlace?.tier ?? 'discovery';
  }

  bool get isCore => tier == 'core_destination';

  String? get openingHours => override?.openingHours ?? addition?.openingHours ?? rawPlace?.openingHours;
  bool get hasOpeningHours => openingHours != null && openingHours!.trim().isNotEmpty;

  String? get primaryImagePath => override?.primaryImagePath ?? addition?.primaryImagePath ?? rawPlace?.primaryImagePath;
  bool get hasImage => primaryImagePath != null && primaryImagePath!.trim().isNotEmpty;

  String? get website => override?.website ?? addition?.website ?? rawPlace?.website;
  String? get phone => override?.phone ?? addition?.phone ?? rawPlace?.phone;
  String? get description => override?.description ?? addition?.description;

  int? get recommendedVisitMinutes => addition?.recommendedVisitMinutes ?? rawPlace?.recommendedVisitMinutes;
  int? get familyFriendly => addition?.familyFriendly ?? rawPlace?.familyFriendly;
  String? get bestTime => addition?.bestTime ?? rawPlace?.bestTime;

  double get travelRelevanceScore => rawPlace?.travelRelevanceScore ?? (isCore ? 0.95 : 0.75);
  double get prominenceScore => rawPlace?.prominenceScore ?? (isCore ? 0.90 : 0.70);

  FieldProvenanceInfo getProvenance(String fieldName) {
    if (isManuallyAdded) {
      return FieldProvenanceInfo(
        fieldName: fieldName,
        currentValue: _getValue(fieldName),
        origin: FieldOrigin.manualAddition,
        sourceLabel: 'MANUAL ADDITION (${addition!.author})',
        verifiedDate: addition!.createdAt,
      );
    }

    if (override != null && _isFieldOverridden(fieldName)) {
      final source = override!.fieldSources[fieldName] ?? 'MANUALLY VERIFIED';
      return FieldProvenanceInfo(
        fieldName: fieldName,
        currentValue: _getValue(fieldName),
        previousValue: override!.previousValues[fieldName] ?? _getRawValue(fieldName),
        origin: FieldOrigin.humanOverride,
        sourceLabel: '$source (${override!.author})',
        verifiedDate: override!.updatedAt,
      );
    }

    // Default to provider
    final rawVal = _getRawValue(fieldName);
    String provider = 'Normalized Provider';
    if (rawPlace != null && rawPlace!.sources.isNotEmpty) {
      provider = rawPlace!.sources.map((s) => s.source.toUpperCase()).join(' + ');
    } else if (rawPlace?.wikidataId != null && rawPlace!.wikidataId!.isNotEmpty) {
      provider = 'Wikidata / OpenStreetMap';
    }

    return FieldProvenanceInfo(
      fieldName: fieldName,
      currentValue: rawVal,
      origin: rawVal != null ? FieldOrigin.trustedProvider : FieldOrigin.unknown,
      sourceLabel: rawVal != null ? provider : 'UNKNOWN',
    );
  }

  bool _isFieldOverridden(String field) {
    if (override == null) return false;
    switch (field) {
      case 'name':
        return override!.name != null;
      case 'opening_hours':
        return override!.openingHours != null;
      case 'coordinates':
      case 'latitude':
      case 'longitude':
        return override!.latitude != null || override!.longitude != null;
      case 'category':
        return override!.category != null;
      case 'primary_image_path':
      case 'image':
        return override!.primaryImagePath != null;
      case 'tier':
        return override!.tier != null || override!.isCore != null;
      case 'website':
        return override!.website != null;
      case 'phone':
        return override!.phone != null;
      default:
        return false;
    }
  }

  dynamic _getValue(String field) {
    switch (field) {
      case 'name':
        return name;
      case 'opening_hours':
        return openingHours;
      case 'latitude':
        return latitude;
      case 'longitude':
        return longitude;
      case 'category':
        return category;
      case 'tier':
        return tier;
      case 'image':
      case 'primary_image_path':
        return primaryImagePath;
      case 'website':
        return website;
      case 'phone':
        return phone;
      default:
        return null;
    }
  }

  dynamic _getRawValue(String field) {
    if (rawPlace == null) return null;
    switch (field) {
      case 'name':
        return rawPlace!.name;
      case 'opening_hours':
        return rawPlace!.openingHours;
      case 'latitude':
        return rawPlace!.latitude;
      case 'longitude':
        return rawPlace!.longitude;
      case 'category':
        return rawPlace!.category;
      case 'tier':
        return rawPlace!.tier;
      case 'image':
      case 'primary_image_path':
        return rawPlace!.primaryImagePath;
      case 'website':
        return rawPlace!.website;
      case 'phone':
        return rawPlace!.phone;
      default:
        return null;
    }
  }

  /// Converts this resolved curated place into a `LabPlace`
  /// ensuring complete compatibility with all existing widgets and evaluators.
  LabPlace toLabPlace() {
    if (isManuallyAdded) {
      return addition!.toLabPlace();
    }

    final base = rawPlace!;
    final List<String> effectiveTags = List.from(base.tags);
    if (isManuallyEdited && !effectiveTags.contains('manually_curated')) {
      effectiveTags.add('manually_curated');
    }

    return LabPlace(
      id: base.id,
      cityId: base.cityId,
      name: name,
      nameHi: nameHi,
      latitude: latitude,
      longitude: longitude,
      address: address,
      category: category,
      subcategory: subcategory,
      primaryEntityType: base.primaryEntityType,
      tier: tier,
      travelRelevanceScore: travelRelevanceScore,
      prominenceScore: prominenceScore,
      recommendedVisitMinutes: recommendedVisitMinutes,
      tourismPriority: base.tourismPriority,
      familyFriendly: familyFriendly,
      bestTime: bestTime,
      website: website,
      phone: phone,
      openingHours: openingHours,
      overtureId: base.overtureId,
      osmId: base.osmId,
      wikidataId: base.wikidataId,
      foursquareId: base.foursquareId,
      wikivoyageListingId: base.wikivoyageListingId,
      qualityOverall: base.qualityOverall,
      anomalyScore: base.anomalyScore,
      primaryImagePath: primaryImagePath,
      thumbnailImagePath: base.thumbnailImagePath,
      generatedAt: base.generatedAt,
      tags: effectiveTags,
      images: base.images,
      sources: base.sources,
    );
  }
}
