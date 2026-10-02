import 'dart:math';

import '../domain/curation/curated_place.dart';
import '../domain/curation/curation_issue.dart';
import '../domain/curation/place_addition.dart';
import '../domain/curation/place_exclusion.dart';
import '../domain/curation/place_override.dart';
import '../domain/curation/place_review.dart';
import '../domain/lab_place.dart';
import '../city_admin/contracts/curation_repository_contract.dart';
import 'curation_repository.dart';
import '../review/models/inbox_decision.dart';
import '../review/models/review_candidate.dart';

class CurationSummary {
  Map<String, int> toJson() => {
    'total_overrides': totalOverrides,
    'total_additions': totalAdditions,
    'total_exclusions': totalExclusions,
    'total_reviews': totalReviews,
    'total_issues': totalIssues,
    'open_issues': openIssues,
    'images_fixed': imagesFixed,
    'hours_fixed': hoursFixed,
    'coords_fixed': coordsFixed,
    'categories_fixed': categoriesFixed,
  };
  final int totalOverrides;
  final int totalAdditions;
  final int totalExclusions;
  final int totalReviews;
  final int totalIssues;
  final int openIssues;
  final int imagesFixed;
  final int hoursFixed;
  final int coordsFixed;
  final int categoriesFixed;

  const CurationSummary({
    required this.totalOverrides,
    required this.totalAdditions,
    required this.totalExclusions,
    required this.totalReviews,
    required this.totalIssues,
    required this.openIssues,
    required this.imagesFixed,
    required this.hoursFixed,
    required this.coordsFixed,
    required this.categoriesFixed,
  });
}

class CurationService {
  /// Derive the effective view from the single durable inbox decision store.
  /// Reload persisted curation first when changing or undoing a decision.
  void applyInboxDecisions(
    List<ReviewCandidate> candidates,
    Map<String, InboxDecision> decisions,
    Set<String> publishedIds,
  ) {
    for (final c in candidates) {
      final d = decisions[c.canonicalId];
      if (d == null || !d.isResolved) continue;
      if (d.verdict == InboxVerdict.rejected) {
        if (publishedIds.contains(c.canonicalId)) {
          _exclusions[c.canonicalId] = PlaceExclusion(
            placeId: c.canonicalId,
            cityId: d.cityId,
            placeName: c.name,
            reason: 'inbox_exclusion',
            notes: d.verdictNote,
            excludedBy: d.author,
            timestamp: d.decidedAt,
          );
        }
      } else if (!publishedIds.contains(c.canonicalId)) {
        _additions.putIfAbsent(
          c.canonicalId,
          () => PlaceAddition(
            id: c.canonicalId,
            cityId: d.cityId,
            name: c.name,
            nameHi: c.nameHi,
            category: c.category,
            subcategory: c.subcategory,
            tier: c.tier,
            latitude: c.latitude,
            longitude: c.longitude,
            address: c.address,
            openingHours: c.openingHours,
            website: c.website,
            phone: c.phone,
            description: c.prose,
            author: d.author,
            createdAt: d.decidedAt,
            evidenceSource: 'DataFactory review candidate ${c.canonicalId}',
            notes: d.verdictNote,
          ),
        );
      }
    }
  }

  final CurationRepositoryContract repository;
  String currentContributor;

  // Active City Caches
  final Map<String, PlaceOverride> _overrides = {};
  final Map<String, PlaceAddition> _additions = {};
  final Map<String, PlaceExclusion> _exclusions = {};
  final Map<String, PlaceReview> _reviews = {};
  final Map<String, CurationIssue> _issues = {};

  String? _activeCityId;
  String? get activeCityId => _activeCityId;

  CurationService({
    CurationRepositoryContract? repository,
    this.currentContributor = 'Contributor',
  }) : repository = repository ?? CurationRepository();

  Map<String, PlaceOverride> get overrides => Map.unmodifiable(_overrides);
  Map<String, PlaceAddition> get additions => Map.unmodifiable(_additions);
  Map<String, PlaceExclusion> get exclusions => Map.unmodifiable(_exclusions);
  Map<String, PlaceReview> get reviews => Map.unmodifiable(_reviews);
  Map<String, CurationIssue> get issues => Map.unmodifiable(_issues);

  bool isExcluded(String placeId) => _exclusions.containsKey(placeId);

  Future<void> loadCityCuration(String cityId) async {
    _activeCityId = cityId;
    _overrides.clear();
    _additions.clear();
    _exclusions.clear();
    _reviews.clear();
    _issues.clear();

    final ov = await repository.loadOverrides(cityId);
    for (final item in ov) {
      _overrides[item.placeId] = item;
    }

    final ad = await repository.loadAdditions(cityId);
    for (final item in ad) {
      _additions[item.id] = item;
    }

    final ex = await repository.loadExclusions(cityId);
    for (final item in ex) {
      _exclusions[item.placeId] = item;
    }

    final rv = await repository.loadReviews(cityId);
    for (final item in rv) {
      _reviews[item.placeId] = item;
    }

    final isList = await repository.loadIssues(cityId);
    for (final item in isList) {
      _issues[item.id] = item;
    }
  }

  CuratedPlace resolve(LabPlace rawPlace) {
    return CuratedPlace(
      rawPlace: rawPlace,
      override: _overrides[rawPlace.id],
      exclusion: _exclusions[rawPlace.id],
    );
  }

  CuratedPlace? resolveAddition(String additionId) {
    final add = _additions[additionId];
    if (add == null) return null;
    return CuratedPlace(
      addition: add,
      override: _overrides[additionId],
      exclusion: _exclusions[additionId],
    );
  }

  // ==========================================
  // Mutations & Fix Flow
  // ==========================================

  Future<void> saveFieldOverride({
    required LabPlace place,
    String? name,
    String? category,
    String? subcategory,
    double? latitude,
    double? longitude,
    String? openingHours,
    String? primaryImagePath,
    String? description,
    String? website,
    String? phone,
    String? tier,
    bool? isCore,
    required String fieldName,
    required String evidenceSource,
    dynamic previousValue,
  }) async {
    final existing = _overrides[place.id];
    final sources = Map<String, String>.from(existing?.fieldSources ?? {});
    final prev = Map<String, dynamic>.from(existing?.previousValues ?? {});

    sources[fieldName] = evidenceSource;
    if (previousValue != null) {
      prev[fieldName] = previousValue;
    }

    final updated = PlaceOverride(
      placeId: place.id,
      cityId: place.cityId,
      packVersion: place.generatedAt ?? 'v3',
      name: name ?? existing?.name,
      category: category ?? existing?.category,
      subcategory: subcategory ?? existing?.subcategory,
      latitude: latitude ?? existing?.latitude,
      longitude: longitude ?? existing?.longitude,
      openingHours: openingHours ?? existing?.openingHours,
      primaryImagePath: primaryImagePath ?? existing?.primaryImagePath,
      description: description ?? existing?.description,
      website: website ?? existing?.website,
      tier: tier ?? existing?.tier ?? place.tier,
      isCore: isCore ?? existing?.isCore ?? (place.tier == 'core_destination'),
      fieldSources: sources,
      previousValues: prev,
      author: currentContributor,
      updatedAt: DateTime.now().toIso8601String(),
      verified: true,
    );

    _overrides[place.id] = updated;
    await repository.saveOverride(updated);

    // Auto-resolve any open issue of this type for this place
    await _autoResolveIssueForField(place.id, fieldName);
  }

  Future<void> revertOverride(String cityId, String placeId) async {
    _overrides.remove(placeId);
    await repository.deleteOverride(cityId, placeId);
  }

  Future<void> addPlace(PlaceAddition addition) async {
    _additions[addition.id] = addition;
    await repository.saveAddition(addition);
  }

  Future<void> excludePlace({
    required String cityId,
    required String placeId,
    required String placeName,
    required String reason,
    String? notes,
  }) async {
    final exclusion = PlaceExclusion(
      placeId: placeId,
      cityId: cityId,
      placeName: placeName,
      reason: reason,
      notes: notes,
      excludedBy: currentContributor,
      timestamp: DateTime.now().toIso8601String(),
    );

    _exclusions[placeId] = exclusion;
    await repository.saveExclusion(exclusion);
  }

  Future<void> unexcludePlace(String cityId, String placeId) async {
    _exclusions.remove(placeId);
    await repository.deleteExclusion(cityId, placeId);
  }

  Future<void> recordReview({
    required String cityId,
    required String placeId,
    required String placeName,
    required String tier,
    required String category,
    required String verdict, // 'looks_good' or defect code
    String? issueType,
    String? notes,
  }) async {
    final review = PlaceReview(
      id: 'rev_$placeId',
      placeId: placeId,
      cityId: cityId,
      placeName: placeName,
      tier: tier,
      category: category,
      verdict: verdict,
      issueType: issueType,
      notes: notes,
      reviewer: currentContributor,
      timestamp: DateTime.now().toIso8601String(),
    );

    _reviews[placeId] = review;
    await repository.saveReview(review);
  }

  Future<void> logIssue({
    required String cityId,
    required String placeId,
    required String placeName,
    required String issueType,
    required String note,
    String? assignedTo,
  }) async {
    final issue = CurationIssue(
      id: 'issue_${placeId}_${DateTime.now().millisecondsSinceEpoch}',
      placeId: placeId,
      cityId: cityId,
      placeName: placeName,
      issueType: issueType,
      status: assignedTo != null
          ? CurationIssueStatus.assigned
          : CurationIssueStatus.open,
      assignedTo: assignedTo,
      note: note,
      author: currentContributor,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    _issues[issue.id] = issue;
    await repository.saveIssue(issue);
  }

  Future<void> updateIssueStatus(
    String issueId,
    CurationIssueStatus newStatus, {
    String? resolutionNote,
  }) async {
    final issue = _issues[issueId];
    if (issue == null) return;

    final updated = issue.copyWith(
      status: newStatus,
      updatedAt: DateTime.now().toIso8601String(),
      resolvedAt:
          (newStatus == CurationIssueStatus.fixed ||
              newStatus == CurationIssueStatus.verified)
          ? DateTime.now().toIso8601String()
          : issue.resolvedAt,
      resolutionNote: resolutionNote ?? issue.resolutionNote,
    );

    _issues[issueId] = updated;
    await repository.saveIssue(updated);
  }

  Future<void> _autoResolveIssueForField(
    String placeId,
    String fieldName,
  ) async {
    for (final entry in _issues.entries) {
      final issue = entry.value;
      if (issue.placeId == placeId && issue.isOpen) {
        bool matches = false;
        if (fieldName == 'opening_hours' && issue.issueType.contains('hours')) {
          matches = true;
        }
        if ((fieldName == 'primary_image_path' || fieldName == 'image') &&
            issue.issueType.contains('image')) {
          matches = true;
        }
        if ((fieldName == 'latitude' || fieldName == 'coordinates') &&
            issue.issueType.contains('location')) {
          matches = true;
        }
        if (fieldName == 'category' && issue.issueType.contains('category')) {
          matches = true;
        }

        if (matches) {
          await updateIssueStatus(
            issue.id,
            CurationIssueStatus.fixed,
            resolutionNote: 'Resolved via manual $fieldName override.',
          );
        }
      }
    }
  }

  // ==========================================
  // Incremental Curated Stats Calculator
  // ==========================================

  Map<String, dynamic> computeCuratedStats(Map<String, dynamic> rawStats) {
    final Map<String, dynamic> stats = Map<String, dynamic>.from(rawStats);

    int totalPlaces = (stats['total_places'] as int?) ?? 0;
    int coreTotal = (stats['core_total'] as int?) ?? 0;
    int withImages = (stats['with_images'] as int?) ?? 0;
    int withHours = (stats['with_opening_hours'] as int?) ?? 0;
    int coreWithImages = (stats['core_with_images'] as int?) ?? 0;
    int coreWithHours = (stats['core_with_hours'] as int?) ?? 0;
    int coreOutsideBounds = (stats['core_outside_bounds'] as int?) ?? 0;
    int placesOutsideBounds = (stats['places_outside_bounds'] as int?) ?? 0;

    final categoryCounts = Map<String, int>.from(
      stats['category_counts'] as Map<String, dynamic>? ?? {},
    );
    final tierCounts = Map<String, int>.from(
      stats['tier_counts'] as Map<String, dynamic>? ?? {},
    );

    // 1. Account for Exclusions
    totalPlaces = max(0, totalPlaces - _exclusions.length);

    // 2. Account for Additions
    for (final add in _additions.values) {
      if (_exclusions.containsKey(add.id)) continue;
      totalPlaces += 1;
      if (add.tier == 'core_destination') {
        coreTotal += 1;
        if (add.primaryImagePath != null && add.primaryImagePath!.isNotEmpty) {
          coreWithImages += 1;
        }
        if (add.openingHours != null && add.openingHours!.isNotEmpty) {
          coreWithHours += 1;
        }
      }
      if (add.primaryImagePath != null && add.primaryImagePath!.isNotEmpty) {
        withImages += 1;
      }
      if (add.openingHours != null && add.openingHours!.isNotEmpty) {
        withHours += 1;
      }

      categoryCounts[add.category] = (categoryCounts[add.category] ?? 0) + 1;
      tierCounts[add.tier] = (tierCounts[add.tier] ?? 0) + 1;
    }

    // 3. Account for Overrides
    for (final ov in _overrides.values) {
      if (_exclusions.containsKey(ov.placeId)) continue;

      if (ov.primaryImagePath != null && ov.primaryImagePath!.isNotEmpty) {
        final hadImg =
            ov.previousValues['primary_image_path'] != null &&
            (ov.previousValues['primary_image_path'] as String).isNotEmpty;
        if (!hadImg) {
          withImages += 1;
          if (ov.isCore == true || ov.tier == 'core_destination') {
            coreWithImages += 1;
          }
        }
      }

      if (ov.openingHours != null && ov.openingHours!.isNotEmpty) {
        final hadHours =
            ov.previousValues['opening_hours'] != null &&
            (ov.previousValues['opening_hours'] as String).isNotEmpty;
        if (!hadHours) {
          withHours += 1;
          if (ov.isCore == true || ov.tier == 'core_destination') {
            coreWithHours += 1;
          }
        }
      }

      // Geo fixes
      if (ov.latitude != null && ov.longitude != null) {
        final bool hadGeoIssue =
            (ov.previousValues['had_geo_issue'] == true) ||
            (ov.previousValues['coordinates'] == true) ||
            (ov.previousValues['coordinates'] != null &&
                placesOutsideBounds > 0);
        if (hadGeoIssue) {
          placesOutsideBounds = max(0, placesOutsideBounds - 1);
          if (ov.isCore == true || ov.tier == 'core_destination') {
            coreOutsideBounds = max(0, coreOutsideBounds - 1);
          }
        }
      }

      // Category fixes
      if (ov.category != null && ov.previousValues['category'] != null) {
        final oldCat = ov.previousValues['category'] as String;
        categoryCounts[oldCat] = max(0, (categoryCounts[oldCat] ?? 1) - 1);
        categoryCounts[ov.category!] = (categoryCounts[ov.category!] ?? 0) + 1;
      }
    }

    stats['total_places'] = totalPlaces;
    stats['core_total'] = coreTotal;
    stats['with_images'] = withImages;
    stats['without_images'] = max(0, totalPlaces - withImages);
    stats['with_opening_hours'] = withHours;
    stats['core_with_images'] = coreWithImages;
    stats['core_with_hours'] = coreWithHours;
    stats['core_outside_bounds'] = coreOutsideBounds;
    stats['places_outside_bounds'] = placesOutsideBounds;
    stats['category_counts'] = categoryCounts;
    stats['tier_counts'] = tierCounts;
    stats['curation_summary'] = getSummary();

    return stats;
  }

  CurationSummary getSummary() {
    int imgFixed = 0;
    int hoursFixed = 0;
    int coordsFixed = 0;
    int catFixed = 0;

    for (final ov in _overrides.values) {
      if (ov.primaryImagePath != null) imgFixed++;
      if (ov.openingHours != null) hoursFixed++;
      if (ov.latitude != null || ov.longitude != null) coordsFixed++;
      if (ov.category != null) catFixed++;
    }

    final openCount = _issues.values.where((i) => i.isOpen).length;

    return CurationSummary(
      totalOverrides: _overrides.length,
      totalAdditions: _additions.length,
      totalExclusions: _exclusions.length,
      totalReviews: _reviews.length,
      totalIssues: _issues.length,
      openIssues: openCount,
      imagesFixed: imgFixed,
      hoursFixed: hoursFixed,
      coordsFixed: coordsFixed,
      categoriesFixed: catFixed,
    );
  }

  String generatePrSummary(String cityName) {
    final s = getSummary();
    final totalChanges =
        s.totalOverrides + s.totalAdditions + s.totalExclusions;

    final buf = StringBuffer();
    buf.writeln('### ${cityName.toUpperCase()} CURATION SUMMARY');
    buf.writeln();
    buf.writeln('**Total Curation Changes**: $totalChanges');
    buf.writeln();
    buf.writeln('| Action | Count |');
    buf.writeln('|---|---|');
    buf.writeln('| 📸 Images Updated / Added | ${s.imagesFixed} |');
    buf.writeln('| 🕒 Opening Hours Corrected | ${s.hoursFixed} |');
    buf.writeln('| 📍 Coordinates Corrected | ${s.coordsFixed} |');
    buf.writeln('| 🏷️ Categories Corrected | ${s.categoriesFixed} |');
    buf.writeln('| ➕ New Places Added | ${s.totalAdditions} |');
    buf.writeln('| 🚫 Inappropriate Places Excluded | ${s.totalExclusions} |');
    buf.writeln('| ✅ Manual QA Places Verified | ${s.totalReviews} |');
    buf.writeln('| ⚠️ Open Issues Remaining | ${s.openIssues} |');
    buf.writeln();
    buf.writeln(
      '_Generated automatically by YatraCanvas City Pack Curation Studio._',
    );

    return buf.toString();
  }
}
