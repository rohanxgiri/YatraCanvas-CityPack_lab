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

class AppState extends ChangeNotifier {
  final CityPackRegistry registry = CityPackRegistry();
  final CityPackLoader loader = CityPackLoader();
  final QaRepository qaRepository = QaRepository();
  final QaExportService exportService = QaExportService();

  // Quality & Release Gate Services
  final CityQualityService cityQualityService = const CityQualityService();
  final TravelReadinessService travelReadinessService = const TravelReadinessService();
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

      // Load or create QA Session
      currentSession = await qaRepository.loadSession(pack.id, pack.version);
      tripSelection = TripSelection(
        cityId: pack.id,
        tripDays: 3,
        placeDays: Map<String, int>.from(currentSession?.tripSelections ?? {}),
      );

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

  Future<void> evaluateCityQuality() async {
    if (activePack == null || repository == null) return;
    isEvaluatingQuality = true;
    notifyListeners();

    try {
      qualityStats = await repository!.getQualityStats();
      categoryCoverageMatrix = await repository!.getCategoryCoverageMatrix();

      manualQaSummary = ManualQaSummary.fromQaSession(currentSession);

      dataQualityScore = cityQualityService.calculateScore(
        pack: activePack!,
        dbStats: qualityStats ?? {},
        manualQa: manualQaSummary!,
      );

      travelReadinessScore = travelReadinessService.calculateScore(
        pack: activePack!,
        dbStats: qualityStats ?? {},
      );

      releaseGateResult = releaseGateService.evaluate(
        pack: activePack!,
        dbStats: qualityStats ?? {},
        dataQuality: dataQualityScore!,
        travelReadiness: travelReadinessScore!,
        manualQa: manualQaSummary!,
      );

      dataGaps = dataGapService.analyzeGaps(
        pack: activePack!,
        dbStats: qualityStats ?? {},
      );
    } catch (e) {
      debugPrint('[ERROR] Failed to evaluate city quality: $e');
    } finally {
      isEvaluatingQuality = false;
      notifyListeners();
    }
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
    currentSession = await qaRepository.loadSession(issue.cityId, issue.packVersion);
    await evaluateCityQuality();
  }

  Future<void> deleteIssue(String issueId) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.deleteIssue(activePack!.id, issueId);
    currentSession = await qaRepository.loadSession(activePack!.id, activePack!.version);
    await evaluateCityQuality();
  }

  Future<void> addRandomReview(RandomReviewRecord record) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.addRandomReview(activePack!.id, record);
    currentSession = await qaRepository.loadSession(activePack!.id, activePack!.version);
    await evaluateCityQuality();
  }

  Future<void> addSearchResultReview(SearchResultReviewRecord record) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.addSearchResultReview(activePack!.id, record);
    currentSession = await qaRepository.loadSession(activePack!.id, activePack!.version);
    notifyListeners();
  }

  Future<void> addExpectedPlaceCheck(ExpectedPlaceCheckRecord record) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.addExpectedPlaceCheck(activePack!.id, record);
    currentSession = await qaRepository.loadSession(activePack!.id, activePack!.version);
    notifyListeners();
  }

  Future<void> addScenarioResult(ScenarioResultRecord record) async {
    if (activePack == null || currentSession == null) return;
    await qaRepository.addScenarioResult(activePack!.id, record);
    currentSession = await qaRepository.loadSession(activePack!.id, activePack!.version);
    notifyListeners();
  }

  // --- Test Trip Actions ---
  Future<void> setTripDays(int days) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.setDays(days);
    await qaRepository.saveTripSelection(activePack!.id, tripSelection!.placeDays);
    notifyListeners();
  }

  Future<void> addPlaceToTrip(String placeId, {int day = 1}) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.addPlace(placeId, day: day);
    await qaRepository.saveTripSelection(activePack!.id, tripSelection!.placeDays);
    notifyListeners();
  }

  Future<void> removePlaceFromTrip(String placeId) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.removePlace(placeId);
    await qaRepository.saveTripSelection(activePack!.id, tripSelection!.placeDays);
    notifyListeners();
  }

  Future<void> assignTripDay(String placeId, int day) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.assignDay(placeId, day);
    await qaRepository.saveTripSelection(activePack!.id, tripSelection!.placeDays);
    notifyListeners();
  }

  Future<void> groupTripGeographically(List<LabPlace> places) async {
    if (tripSelection == null || activePack == null) return;
    tripSelection!.groupGeographically(places);
    await qaRepository.saveTripSelection(activePack!.id, tripSelection!.placeDays);
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
