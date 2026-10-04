import 'package:flutter/foundation.dart';

import '../domain/city_pack.dart';
import '../domain/lab_place.dart';
import '../domain/qa_issue.dart';
import '../domain/qa_session.dart';
import '../domain/trip_selection.dart';
import '../data/city_pack_registry.dart';
import '../data/city_pack_loader.dart';
import '../data/local_image_resolver.dart';
import '../data/local_place_repository.dart';
import '../qa/qa_repository.dart';
import '../qa/qa_export_service.dart';
import '../quality/models/data_gap_item.dart';
import '../quality/models/data_quality_score.dart';
import '../quality/models/manual_qa_summary.dart';
import '../quality/models/release_gate_result.dart';
import '../quality/models/travel_readiness_score.dart';
import '../quality/services/city_quality_service.dart';
import '../quality/services/data_gap_service.dart';
import '../quality/services/qa_sampling_service.dart';
import '../quality/services/release_gate_service.dart';
import '../quality/services/travel_readiness_service.dart';
import '../domain/curation/curated_place.dart';
import '../domain/curation/curation_issue.dart';
import '../domain/curation/place_addition.dart';
import '../curation/curation_repository.dart';
import '../curation/curation_service.dart';
import '../curation/curated_image_import_service.dart';
import '../review/models/review_candidate.dart';
import '../review/models/inbox_decision.dart';
import '../review/services/review_manifest_loader.dart';
import '../review/repository/inbox_decision_repository.dart';
import '../review/models/identity_conflict.dart';
import '../quality/services/media_integrity_service.dart';

class AppState extends ChangeNotifier {
  final CityPackRegistry registry = CityPackRegistry();
  final CityPackLoader loader = CityPackLoader();
  final QaRepository qaRepository = QaRepository();
  final QaExportService exportService = QaExportService();

  // Curation System (Human overrides, additions, exclusions)
  final CurationRepository curationRepository = CurationRepository();
  late final CurationService curationService = CurationService(
    repository: curationRepository,
  );
  final CuratedImageImportService imageImportService =
      CuratedImageImportService();

  bool isAdminMode = false;
  String contributorName = 'Contributor';

  // Quality & Release Gate Services
  final CityQualityService cityQualityService = const CityQualityService();
  final TravelReadinessService travelReadinessService =
      const TravelReadinessService();
  final ReleaseGateService releaseGateService = const ReleaseGateService();
  final DataGapService dataGapService = const DataGapService();
  final QaSamplingService qaSamplingService = const QaSamplingService();

  List<CityPack> availablePacks = [];
  bool isLoadingPacks = false;
  String? packLoadError;

  CityPack? activePack;
  LocalPlaceRepository? repository;
  QaSession? currentSession;
  TripSelection? tripSelection;
  Set<String> userInterests = {};

  // Quality Engine Assessments
  DataQualityScore? dataQualityScore;
  TravelReadinessScore? travelReadinessScore;
  ReleaseGateResult? releaseGateResult;
  ManualQaSummary? manualQaSummary;
  List<DataGapItem> dataGaps = [];
  Map<String, dynamic>? qualityStats;
  List<Map<String, dynamic>> categoryCoverageMatrix = [];
  bool isEvaluatingQuality = false;

  // ── Review Inbox ──────────────────────────────────────────────────────
  final ReviewManifestLoader _manifestLoader = ReviewManifestLoader();
  final InboxDecisionRepository inboxDecisionRepo = InboxDecisionRepository();

  /// DataFactory review candidates for the active pack, sorted for inbox.
  List<ReviewCandidate> reviewCandidates = [];

  /// Human decisions keyed by canonical_id.
  Map<String, InboxDecision> inboxDecisions = {};

  /// Error or warning from the last manifest load attempt.
  String? reviewManifestWarning;

  /// Whether review_candidates.json was absent when the pack was opened.
  bool reviewManifestMissing = false;
  List<String> mediaIntegrityBlockers = [];
  List<IdentityConflict> identityConflicts = [];

  int get unresolvedHighPriorityCount => reviewCandidates
      .where(
        (c) =>
            c.reviewPriority.sortOrder <= ReviewPriority.high.sortOrder &&
            !(inboxDecisions[c.canonicalId]?.isResolved ?? false),
      )
      .length;

  int get unresolvedReviewCount => reviewCandidates
      .where((c) => !(inboxDecisions[c.canonicalId]?.isResolved ?? false))
      .length;

  // Diagnostics & Transparency
  bool strictOfflineMode = false;
  int remotePoiRequests = 0;
  int backendRequests = 0;
  int lastQueryLatencyMs = 0;

  AppState() {
    CityPackLoader.initFfiIfNeeded();
    loadPacks();
  }

  Future<void> loadPacks() async {
    isLoadingPacks = true;
    packLoadError = null;
    notifyListeners();

    try {
      availablePacks = await registry.loadAvailablePacks();
    } catch (e) {
      packLoadError = 'Failed to discover city packs: $e';
    } finally {
      isLoadingPacks = false;
      notifyListeners();
    }
  }

  Future<void> openPack(CityPack pack) async {
    final sw = Stopwatch()..start();
    try {
      final context = await loader.openCityPack(pack.id);
      final imageResolver = LocalImageResolver(
        cityId: pack.id,
        imagesDirPath: context.imagesDirPath,
      );
      repository = LocalPlaceRepository(
        database: context.packDatabase,
        imageResolver: imageResolver,
      );
      activePack = pack;
      curationService.sourcePackVersion = pack.version;

      // Load or create QA Session
      currentSession = await qaRepository.loadSession(pack.id, pack.version);
      tripSelection = TripSelection(
        cityId: pack.id,
        tripDays: 3,
        placeDays: Map<String, int>.from(currentSession?.tripSelections ?? {}),
      );

      // Load Curation System state (overrides, additions, exclusions, reviews, issues)
      curationService.currentContributor = contributorName;
      await curationService.loadCityCuration(pack.id);
      for (final row in curationService.overrides.values) {
        if (row.aliases != null) {
          repository!.database.aliases[row.placeId] = row.aliases!;
        }
      }

      // Load Review Inbox (DataFactory review_candidates.json + human decisions)
      await loadReviewManifest(pack.id);

      sw.stop();
      lastQueryLatencyMs = sw.elapsedMilliseconds;
      notifyListeners();

      // Automatically evaluate Quality & Release Gate upon loading pack
      await evaluateCityQuality();
    } catch (e) {
      debugPrint('[ERROR] Failed to open pack ${pack.id}: $e');
      rethrow;
    }
  }

  // ── Review Inbox Actions ──────────────────────────────────────────────

  /// Loads review_candidates.json and previously saved inbox decisions.
  /// Detects "changed since review" for any candidate that changed in a
  /// DataFactory regeneration.
  Future<void> loadReviewManifest(String cityId) async {
    final published =
        await repository?.database.db.query('places', columns: ['id']) ?? [];
    final result = await _manifestLoader.load(
      cityId,
      publishedIds: published.map((row) => row['id'] as String).toSet(),
    );
    reviewManifestMissing = result.isMissing;
    identityConflicts = result.conflicts;
    reviewManifestWarning = result.warnings.isNotEmpty
        ? result.warnings.join(' ')
        : result.error;

    final sorted = ReviewManifestLoader.sortForInbox(result.candidates);

    // Load previously saved decisions
    final saved = await inboxDecisionRepo.loadDecisions(cityId);
    final availableIds = {
      ...sorted.map((c) => c.canonicalId),
      ...identityConflicts.map((c) => c.canonicalId),
    };
    final stale = saved.keys.where((id) => !availableIds.contains(id)).toList();
    if (stale.isNotEmpty) {
      reviewManifestWarning = [
        ?reviewManifestWarning,
        '${stale.length} saved decisions refer to missing candidates: ${stale.join(", ")}. '
            'They are preserved but not applied. Refresh the source to restore missing evidence before certification.',
      ].join(' ');
    }
    if (inboxDecisionRepo.loadWarnings.isNotEmpty) {
      reviewManifestWarning = [
        ?reviewManifestWarning,
        ...inboxDecisionRepo.loadWarnings,
      ].join(' ');
    }

    // Run changed-since-review detection
    final updated = <String, InboxDecision>{};
    for (final candidate in sorted) {
      final existing = saved[candidate.canonicalId];
      if (existing != null) {
        final changed = inboxDecisionRepo.detectChanges(
          existing: existing,
          fresh: candidate,
        );
        if (changed != null) {
          // Persist the updated (changed) decision automatically
          await inboxDecisionRepo.saveDecision(changed);
          updated[candidate.canonicalId] = changed;
        } else {
          updated[candidate.canonicalId] = existing;
        }
      }
    }

    reviewCandidates = sorted;
    inboxDecisions = updated;
    notifyListeners();
  }

  /// Records a human decision for a DataFactory review candidate.
  Future<void> saveInboxDecision(InboxDecision decision) async {
    await inboxDecisionRepo.saveDecision(decision);
    inboxDecisions = Map.from(inboxDecisions)
      ..[decision.canonicalId] = decision;
    await evaluateCityQuality();
    notifyListeners();
  }

  /// Removes a human decision, restoring DataFactory source behaviour.
  Future<void> removeInboxDecision(String canonicalId) async {
    if (activePack == null) return;
    await inboxDecisionRepo.removeDecision(activePack!.id, canonicalId);
    final updated = Map<String, InboxDecision>.from(inboxDecisions);
    updated.remove(canonicalId);
    inboxDecisions = updated;
    await evaluateCityQuality();
    notifyListeners();
  }

  /// Quick helper to build a snapshot from a candidate for persisting with a
  /// decision.
  InboxDecisionSnapshot snapshotOf(ReviewCandidate c) {
    return InboxDecisionSnapshot(
      semanticFields: InboxDecisionRepository.semanticFieldsOf(c),
      travelRelevanceReason: c.travelRelevanceReason,
      travelRelevanceScore: c.travelRelevanceScore,
      confidence: c.confidence,
      suggestedAction: c.suggestedAction,
      missingFields: List.from(c.missingFields),
    );
  }

  Future<void> evaluateCityQuality() async {
    if (activePack == null || repository == null) return;
    isEvaluatingQuality = true;
    notifyListeners();

    try {
      await curationService.loadCityCuration(activePack!.id);
      final published = await repository!.database.db.query(
        'places',
        columns: ['id'],
      );
      curationService.applyInboxDecisions(
        reviewCandidates,
        inboxDecisions,
        published.map((p) => p['id'] as String).toSet(),
      );
      final rawStats = await repository!.getQualityStats();
      qualityStats = curationService.computeCuratedStats(rawStats);
      categoryCoverageMatrix = await repository!.getCategoryCoverageMatrix();

      // Combine git-tracked reviews/issues with any session reviews/issues
      final combinedReviews = [
        ...curationService.reviews.values,
        ...(currentSession?.randomReviews ?? []).where(
          (review) => !curationService.reviews.containsKey(review.placeId),
        ),
      ];
      final combinedIssues = [
        ...curationService.issues.values,
        ...(currentSession?.issues ?? []),
      ];

      manualQaSummary = ManualQaSummary.fromCuration(
        reviews: combinedReviews,
        issues: combinedIssues,
      );

      dataQualityScore = cityQualityService.calculateScore(
        pack: activePack!,
        dbStats: qualityStats ?? {},
        manualQa: manualQaSummary!,
      );

      travelReadinessScore = travelReadinessService.calculateScore(
        pack: activePack!,
        dbStats: qualityStats ?? {},
      );

      mediaIntegrityBlockers = await MediaIntegrityService().validate(
        activePack!.id,
        excluded: curationService.exclusions.keys.toSet(),
        overrides: {
          for (final e in curationService.overrides.entries)
            if (e.value.primaryImagePath != null)
              e.key: e.value.primaryImagePath!,
        },
      );
      releaseGateResult = releaseGateService.evaluate(
        pack: activePack!,
        dbStats: qualityStats ?? {},
        dataQuality: dataQualityScore!,
        travelReadiness: travelReadinessScore!,
        manualQa: manualQaSummary!,
        reviewCandidates: reviewCandidates,
        inboxDecisions: inboxDecisions,
        reviewManifestProblem: reviewManifestWarning,
        mediaIntegrityBlockers: mediaIntegrityBlockers,
      );

      dataGaps = dataGapService.analyzeGaps(
        pack: activePack!,
        dbStats: qualityStats ?? {},
      );
    } catch (e) {
      debugPrint('[ERROR] Failed to evaluate city quality: $e');
      releaseGateResult = ReleaseGateResult(
        status: ReleaseStatus.blocked,
        criticalBlockers: [
          'Quality evaluation failed: $e. Reopen the city or refresh valid source data before certification.',
        ],
        warnings: const [],
        checks: const {'quality_evaluation_valid': false},
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );
    } finally {
      isEvaluatingQuality = false;
      notifyListeners();
    }
  }

  void toggleAdminMode() {
    isAdminMode = !isAdminMode;
    notifyListeners();
  }

  void setContributorName(String name) {
    contributorName = name.trim().isEmpty ? 'Contributor' : name.trim();
    curationService.currentContributor = contributorName;
    notifyListeners();
  }

  Future<CuratedPlace?> getCuratedPlaceById(String id) async {
    if (repository == null) return null;
    final addition = curationService.resolveAddition(id);
    if (addition != null) return addition;

    final raw = await repository!.getPlaceById(id);
    if (raw == null) return null;
    return curationService.resolve(raw);
  }

  Future<List<CuratedPlace>> getCuratedPlaces({
    String query = '',
    String filter = 'all',
    String? category,
    int limit = 100,
    int offset = 0,
  }) async {
    if (repository == null) return [];

    List<LabPlace> basePlaces = [];
    const repairFilters = {
      'missing_image',
      'fallback_image',
      'test_only_image',
      'missing_hours',
      'unknown_hours',
      'unverified_hours',
      'missing_description',
    };
    if (repairFilters.contains(filter)) {
      final raw = await repository!.search(
        query: query.trim(),
        category: category == 'all' ? null : category,
        limit: 100000,
      );
      final candidates = [
        for (final p in raw) curationService.resolve(p),
        for (final id in curationService.additions.keys)
          if (curationService.resolveAddition(id) != null)
            curationService.resolveAddition(id)!,
      ];
      bool matches(CuratedPlace p) {
        if (p.isExcluded ||
            (category != null && category != 'all' && p.category != category)) {
          return false;
        }
        if (query.isNotEmpty &&
            p.isManuallyAdded &&
            !p.name.toLowerCase().contains(query.toLowerCase()) &&
            !p.id.contains(query)) {
          return false;
        }
        final metadata = repository!.database.reviewMetadata[p.id] ?? {};
        final hours =
            p.override?.openingHoursStatus ??
            metadata['hours_state'] ??
            (p.hasOpeningHours ? 'UNVERIFIED' : 'UNKNOWN');
        final source = p.override?.fieldSources['primary_image_path'] ?? '';
        final media = p.override?.primaryImagePath != null
            ? (source.contains('UNVERIFIED_TEST_ONLY')
                  ? 'TEST_ONLY_REAL'
                  : 'MANUAL')
            : metadata['media_class'];
        switch (filter) {
          case 'missing_image':
            return !p.hasImage;
          case 'fallback_image':
            return p.primaryImagePath?.toLowerCase().contains('fallback') ==
                    true ||
                media == 'AI_FALLBACK' ||
                media == 'GENERIC_FALLBACK';
          case 'test_only_image':
            return media == 'TEST_ONLY_REAL';
          case 'missing_hours':
          case 'unknown_hours':
            return !p.hasOpeningHours || hours == 'UNKNOWN';
          case 'unverified_hours':
            return p.hasOpeningHours && hours == 'UNVERIFIED';
          case 'missing_description':
            return p.description?.trim().isNotEmpty != true;
        }
        return false;
      }

      return candidates.where(matches).skip(offset).take(limit).toList();
    }

    switch (filter) {
      case 'needs_attention':
        final p1 = await repository!.getPlacesForGap(
          'core_missing_images',
          limit: limit,
        );
        final p2 = await repository!.getPlacesForGap(
          'core_missing_hours',
          limit: limit,
        );
        final p3 = await repository!.getPlacesForGap(
          'core_geo_issue',
          limit: limit,
        );
        final seen = <String>{};
        basePlaces = [
          ...p1,
          ...p2,
          ...p3,
        ].where((p) => seen.add(p.id)).toList();
        break;
      case 'core':
        basePlaces = await repository!.getByTier(
          tier: 'core_destination',
          limit: limit,
          offset: offset,
        );
        break;
      case 'manually_edited':
        final editedIds = curationService.overrides.keys.toList();
        basePlaces = await repository!.getPlacesByIds(editedIds);
        break;
      case 'missing_image':
        basePlaces = await repository!.getPlacesForGap(
          'missing_images',
          limit: limit,
          offset: offset,
          category: category,
        );
        break;
      case 'missing_hours':
        basePlaces = await repository!.getPlacesForGap(
          'missing_hours',
          limit: limit,
          offset: offset,
          category: category,
        );
        break;
      case 'location_issue':
        basePlaces = await repository!.getPlacesForGap(
          'geo_outliers',
          limit: limit,
          offset: offset,
        );
        break;
      case 'duplicate':
        basePlaces = await repository!.getPlacesForGap(
          'duplicate_coords',
          limit: limit,
          offset: offset,
        );
        break;
      case 'excluded':
        final excludedIds = curationService.exclusions.keys.toList();
        basePlaces = await repository!.getPlacesByIds(excludedIds);
        break;
      case 'all':
      default:
        if (query.trim().isNotEmpty) {
          basePlaces = await repository!.search(
            query: query.trim(),
            category: (category != null && category.toLowerCase() != 'all')
                ? category
                : null,
            limit: limit,
            offset: offset,
          );
        } else if (category != null && category.toLowerCase() != 'all') {
          basePlaces = await repository!.getByCategory(
            category: category,
            limit: limit,
            offset: offset,
          );
        } else {
          basePlaces = await repository!.getByTier(
            tier: 'core_destination',
            limit: 30,
          );
          final rec = await repository!.search(
            query: '',
            limit: limit - basePlaces.length,
            offset: offset,
          );
          final seen = <String>{};
          basePlaces = [
            ...basePlaces,
            ...rec,
          ].where((p) => seen.add(p.id)).toList();
        }
        break;
    }

    // Map base places to CuratedPlace
    final List<CuratedPlace> curatedList = basePlaces
        .map((p) => curationService.resolve(p))
        .toList();

    // Ingest manual additions
    for (final add in curationService.additions.values) {
      if (filter == 'excluded' &&
          !curationService.exclusions.containsKey(add.id)) {
        continue;
      }
      if (filter == 'core' && add.tier != 'core_destination') {
        continue;
      }
      if (category != null &&
          category.toLowerCase() != 'all' &&
          add.category != category) {
        continue;
      }
      if (query.trim().isNotEmpty &&
          !add.name.toLowerCase().contains(query.toLowerCase())) {
        continue;
      }

      final curatedAdd = curationService.resolveAddition(add.id);
      if (curatedAdd != null) {
        curatedList.insert(0, curatedAdd);
      }
    }

    if (filter != 'excluded') {
      return curatedList.where((p) => !p.isExcluded).toList();
    }
    return curatedList;
  }

  // --- Curation Actions ---
  Future<ImportedPlaceImage> importPlaceImage({
    required LabPlace place,
    required Uint8List sourceBytes,
    required String originalFilename,
    required String source,
    required String sourcePage,
    String author = '',
    required String license,
    required String licenseUrl,
  }) async {
    final pack = activePack;
    if (pack == null) {
      throw const ImageImportException(
        'Open a city pack before importing a photo.',
      );
    }

    final imported = await imageImportService.importImage(
      cityId: pack.id,
      placeId: place.id,
      sourceBytes: sourceBytes,
      originalFilename: originalFilename,
      source: source,
      sourcePage: sourcePage,
      author: author,
      license: license,
      licenseUrl: licenseUrl,
      contributor: contributorName,
    );

    await saveFieldOverride(
      place: place,
      primaryImagePath: imported.primaryImagePath,
      fieldName: 'primary_image_path',
      evidenceSource: '$source [License: $license]',
      previousValue: place.primaryImagePath,
    );
    return imported;
  }

  Future<void> saveFieldOverride({
    required LabPlace place,
    String? name,
    String? nameHi,
    List<String>? aliases,
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
    await curationService.saveFieldOverride(
      place: place,
      name: name,
      nameHi: nameHi,
      aliases: aliases,
      category: category,
      subcategory: subcategory,
      latitude: latitude,
      longitude: longitude,
      openingHours: openingHours,
      primaryImagePath: primaryImagePath,
      description: description,
      website: website,
      phone: phone,
      tier: tier,
      isCore: isCore,
      fieldName: fieldName,
      evidenceSource: evidenceSource,
      previousValue: previousValue,
    );
    if (aliases != null) repository?.database.aliases[place.id] = aliases;
    await evaluateCityQuality();
  }

  Future<void> revertOverride(String placeId) async {
    if (activePack == null) return;
    await curationService.revertOverride(activePack!.id, placeId);
    await evaluateCityQuality();
  }

  Future<void> addManualPlace(PlaceAddition addition) async {
    await curationService.addPlace(addition);
    await evaluateCityQuality();
  }

  Future<void> excludePlace({
    required String placeId,
    required String placeName,
    required String reason,
    String? notes,
  }) async {
    if (activePack == null) return;
    await curationService.excludePlace(
      cityId: activePack!.id,
      placeId: placeId,
      placeName: placeName,
      reason: reason,
      notes: notes,
    );
    await evaluateCityQuality();
  }

  Future<void> unexcludePlace(String placeId) async {
    if (activePack == null) return;
    await curationService.unexcludePlace(activePack!.id, placeId);
    await evaluateCityQuality();
  }

  Future<void> recordPlaceReview({
    required String placeId,
    required String placeName,
    required String tier,
    required String category,
    required String verdict,
    String? issueType,
    String? notes,
  }) async {
    if (activePack == null) return;
    await curationService.recordReview(
      cityId: activePack!.id,
      placeId: placeId,
      placeName: placeName,
      tier: tier,
      category: category,
      verdict: verdict,
      issueType: issueType,
      notes: notes,
    );

    // Also record in QaSession for legacy compatibility
    final rec = RandomReviewRecord(
      placeId: placeId,
      placeName: placeName,
      tier: tier,
      category: category,
      result: verdict,
      note: notes,
      timestamp: DateTime.now().toIso8601String(),
    );
    await qaRepository.addRandomReview(activePack!.id, rec);
    currentSession = await qaRepository.loadSession(
      activePack!.id,
      activePack!.version,
    );

    await evaluateCityQuality();
  }

  Future<void> logCurationIssue({
    required String placeId,
    required String placeName,
    required String issueType,
    required String note,
    String? assignedTo,
  }) async {
    if (activePack == null) return;
    await curationService.logIssue(
      cityId: activePack!.id,
      placeId: placeId,
      placeName: placeName,
      issueType: issueType,
      note: note,
      assignedTo: assignedTo,
    );
    await evaluateCityQuality();
  }

  Future<void> updateCurationIssueStatus(
    String issueId,
    CurationIssueStatus status, {
    String? resolutionNote,
  }) async {
    await curationService.updateIssueStatus(
      issueId,
      status,
      resolutionNote: resolutionNote,
    );
    await evaluateCityQuality();
  }

  Future<Map<String, String>?> exportCertifiedRelease() async {
    if (activePack == null ||
        dataQualityScore == null ||
        travelReadinessScore == null ||
        releaseGateResult == null ||
        manualQaSummary == null) {
      return null;
    }
    return exportService.exportCertifiedRelease(
      pack: activePack!,
      dataQuality: dataQualityScore!,
      travelReadiness: travelReadinessScore!,
      releaseGate: releaseGateResult!,
      manualQa: manualQaSummary!,
      dbStats: qualityStats,
      reviewState: {
        'selectable_candidates': reviewCandidates.length,
        'resolved': inboxDecisions.values.where((d) => d.isResolved).length,
        'needs_research': inboxDecisions.values
            .where((d) => d.verdict == InboxVerdict.needsResearch)
            .length,
        'changed_since_review': inboxDecisions.values
            .where((d) => d.changedSinceReview)
            .length,
        'manifest_warning': reviewManifestWarning,
      },
    );
  }

  void closeActivePack() {
    activePack = null;
    repository = null;
    currentSession = null;
    tripSelection = null;
    userInterests.clear();
    dataQualityScore = null;
    travelReadinessScore = null;
    releaseGateResult = null;
    manualQaSummary = null;
    dataGaps.clear();
    qualityStats = null;
    categoryCoverageMatrix.clear();
    // Clear review inbox
    reviewCandidates = [];
    inboxDecisions = {};
    reviewManifestWarning = null;
    reviewManifestMissing = false;
    notifyListeners();
  }

  void setUserInterests(Iterable<String> interests) {
    userInterests = interests.toSet();
    notifyListeners();
  }

  void toggleStrictOffline(bool value) {
    strictOfflineMode = value;
    notifyListeners();
  }

  void recordQueryLatency(int latencyMs) {
    lastQueryLatencyMs = latencyMs;
    notifyListeners();
  }

  // --- QA Actions ---
  Future<void> reportIssue(QaIssue issue) async {
    if (currentSession == null) return;
    await qaRepository.addIssue(issue);
    currentSession = await qaRepository.loadSession(
      issue.cityId,
      issue.packVersion,
    );
    await evaluateCityQuality();
  }

  Future<void> deleteIssue(String issueId) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.deleteIssue(activePack!.id, issueId);
    currentSession = await qaRepository.loadSession(
      activePack!.id,
      activePack!.version,
    );
    await evaluateCityQuality();
  }

  Future<void> addRandomReview(RandomReviewRecord record) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.addRandomReview(activePack!.id, record);
    currentSession = await qaRepository.loadSession(
      activePack!.id,
      activePack!.version,
    );
    await evaluateCityQuality();
  }

  Future<void> addSearchResultReview(SearchResultReviewRecord record) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.addSearchResultReview(activePack!.id, record);
    currentSession = await qaRepository.loadSession(
      activePack!.id,
      activePack!.version,
    );
    notifyListeners();
  }

  Future<void> addExpectedPlaceCheck(ExpectedPlaceCheckRecord record) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.addExpectedPlaceCheck(activePack!.id, record);
    currentSession = await qaRepository.loadSession(
      activePack!.id,
      activePack!.version,
    );
    notifyListeners();
  }

  Future<void> addScenarioResult(ScenarioResultRecord record) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.addScenarioResult(activePack!.id, record);
    currentSession = await qaRepository.loadSession(
      activePack!.id,
      activePack!.version,
    );
    notifyListeners();
  }

  // --- Test Trip Actions ---
  Future<void> setTripDays(int days) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.setDays(days);
    await qaRepository.saveTripSelection(
      activePack!.id,
      tripSelection!.placeDays,
    );
    notifyListeners();
  }

  Future<void> addPlaceToTrip(String placeId, {int day = 1}) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.addPlace(placeId, day: day);
    await qaRepository.saveTripSelection(
      activePack!.id,
      tripSelection!.placeDays,
    );
    notifyListeners();
  }

  Future<void> removePlaceFromTrip(String placeId) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.removePlace(placeId);
    await qaRepository.saveTripSelection(
      activePack!.id,
      tripSelection!.placeDays,
    );
    notifyListeners();
  }

  Future<void> assignTripDay(String placeId, int day) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.assignDay(placeId, day);
    await qaRepository.saveTripSelection(
      activePack!.id,
      tripSelection!.placeDays,
    );
    notifyListeners();
  }

  Future<void> groupTripGeographically(List<LabPlace> places) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.groupGeographically(places);
    await qaRepository.saveTripSelection(
      activePack!.id,
      tripSelection!.placeDays,
    );
    notifyListeners();
  }

  Future<QaExportResult?> exportQaReport() async {
    if (activePack == null || currentSession == null || repository == null) {
      return null;
    }
    final stats = await repository!.getQualityStats();
    return exportService.exportReport(
      pack: activePack!,
      session: currentSession!,
      qualityStats: stats,
    );
  }
}
