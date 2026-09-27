// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_database.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_registry.dart';
import 'package:yatracanvas_citypack_lab/quality/models/manual_qa_summary.dart';
import 'package:yatracanvas_citypack_lab/quality/services/city_quality_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/data_gap_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/release_gate_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/travel_readiness_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Evaluate Real Jaipur Pack Quality & Release Gate', () async {
    final registry = CityPackRegistry();
    final packs = await registry.loadAvailablePacks();
    final jaipur = packs.firstWhere((p) => p.id == 'jaipur');

    expect(jaipur, isNotNull);

    // Open DB
    final dbFile = File('assets/city_packs/jaipur/yatracanvas.db');
    final db = await databaseFactory.openDatabase(
      dbFile.absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );

    final packDb = CityPackDatabase(db, 'jaipur');
    final stats = await packDb.getQualityStats();
    final matrix = await packDb.getCategoryCoverageMatrix();

    // Evaluate Quality & Release Gate with 0 initial reviews
    const qualityService = CityQualityService();
    const travelService = TravelReadinessService();
    const releaseService = ReleaseGateService();
    const gapService = DataGapService();

    // 0 reviews completed -> NOT_STARTED
    const initialManualQa = ManualQaSummary(
      state: ManualQaState.notStarted,
      reviewedCount: 0,
      minimumRequired: 50,
      approvedCount: 0,
      issueCount: 0,
      uncertainCount: 0,
      score: null,
    );

    final initialDq = qualityService.calculateScore(
      pack: jaipur,
      dbStats: stats,
      manualQa: initialManualQa,
    );

    final initialTr = travelService.calculateScore(
      pack: jaipur,
      dbStats: stats,
    );

    final initialGate = releaseService.evaluate(
      pack: jaipur,
      dbStats: stats,
      dataQuality: initialDq,
      travelReadiness: initialTr,
      manualQa: initialManualQa,
    );

    final gaps = gapService.analyzeGaps(pack: jaipur, dbStats: stats);

    print('══════════════════════════════════════════════════════════════');
    print('REAL JAIPUR EVALUATION (INITIAL / ZERO MANUAL REVIEWS)');
    print('══════════════════════════════════════════════════════════════');
    print('City: ${jaipur.name} (v${jaipur.version})');
    print('Total Places: ${stats['total_places']}');
    print('Data Quality Score: ${initialDq.overallScore} / 100');
    print('Travel Readiness Score: ${initialTr.overallScore} / 100');
    print('Manual QA Status: ${initialManualQa.displayStatus}');
    print('Release Status: ${initialGate.displayStatus}');
    print('Critical Blockers (${initialGate.criticalBlockers.length}):');
    for (final b in initialGate.criticalBlockers) {
      print('  • ❌ $b');
    }
    print('Warnings (${initialGate.warnings.length}):');
    for (final w in initialGate.warnings) {
      print('  • ⚠️ $w');
    }
    print('Identified Gaps (${gaps.length}):');
    for (final g in gaps) {
      print('  • [${g.severity.name.toUpperCase()}] ${g.title}: ${g.count} places (${g.reason})');
    }
    print('Coverage Matrix Categories (${matrix.length}):');
    for (final r in matrix.take(5)) {
      print('  • ${r['category']}: ${r['total']} places, ${r['with_images']} with photos, ${r['with_hours']} with hours');
    }

    // Now evaluate with a completed manual sample (50 reviews, 2 defects)
    const certifiedManualQa = ManualQaSummary(
      state: ManualQaState.sufficientSample,
      reviewedCount: 50,
      minimumRequired: 50,
      approvedCount: 48,
      issueCount: 2,
      uncertainCount: 0,
      score: 0.96,
    );

    final certifiedDq = qualityService.calculateScore(
      pack: jaipur,
      dbStats: stats,
      manualQa: certifiedManualQa,
    );

    final certifiedGate = releaseService.evaluate(
      pack: jaipur,
      dbStats: stats,
      dataQuality: certifiedDq,
      travelReadiness: initialTr,
      manualQa: certifiedManualQa,
    );

    print('\n══════════════════════════════════════════════════════════════');
    print('REAL JAIPUR EVALUATION (POST-MANUAL QA SAMPLING)');
    print('══════════════════════════════════════════════════════════════');
    print('Data Quality Score: ${certifiedDq.overallScore} / 100');
    print('Travel Readiness Score: ${initialTr.overallScore} / 100');
    print('Manual QA Status: ${certifiedManualQa.displayStatus}');
    print('Release Status: ${certifiedGate.displayStatus}');
    print('Critical Blockers: ${certifiedGate.criticalBlockers.length}');
    print('Warnings: ${certifiedGate.warnings.length}');
    print('══════════════════════════════════════════════════════════════');

    await db.close();
  });
}
