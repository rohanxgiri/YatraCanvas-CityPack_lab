import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_service.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_database.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_registry.dart';
import 'package:yatracanvas_citypack_lab/domain/lab_place.dart';
import 'package:yatracanvas_citypack_lab/quality/models/manual_qa_summary.dart';
import 'package:yatracanvas_citypack_lab/quality/services/city_quality_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/travel_readiness_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/release_gate_service.dart';
import 'package:yatracanvas_citypack_lab/quality/services/media_integrity_service.dart';
import 'package:yatracanvas_citypack_lab/review/services/review_manifest_loader.dart';
import 'package:yatracanvas_citypack_lab/review/repository/inbox_decision_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = createDatabaseFactoryFfi(noIsolate: true);
  test(
    'baseline descriptions survive hydration and effective place resolution',
    () {
      final place = LabPlace.fromMap({
        'id': 'fixture',
        'city_id': 'fixture',
        'name': 'Fixture',
        'category': 'heritage',
        'latitude': 26.9,
        'longitude': 75.8,
        'description': 'Bundled evidence',
      });
      expect(
        CurationService().resolve(place.copyWith(tags: ['test'])).description,
        'Bundled evidence',
      );
      expect(
        CurationService().resolve(place).toLabPlace().description,
        'Bundled evidence',
      );
    },
  );
  test('real cities retain honest blockers with durable curator state', () async {
    final packs = await CityPackRegistry().loadAvailablePacks();
    for (final city in ['jaipur', 'udaipur', 'varanasi']) {
      final watch = Stopwatch()..start();
      final file = File('assets/city_packs/$city/yatracanvas.db');
      final db = await databaseFactory.openDatabase(
        file.absolute.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      try {
        final pack = packs.firstWhere((p) => p.id == city);
        final curation = CurationService();
        await curation.loadCityCuration(city);
        final published = (await db.query(
          'places',
          columns: ['id'],
        )).map((r) => r['id'] as String).toSet();
        final manifest = await ReviewManifestLoader().load(
          city,
          publishedIds: published,
        );
        final decisions = await InboxDecisionRepository().loadDecisions(city);
        curation.applyInboxDecisions(manifest.candidates, decisions, published);
        final stats = curation.computeCuratedStats(
          await CityPackDatabase(db, city).getQualityStats(),
        );
        final qa = ManualQaSummary.fromCuration(
          reviews: curation.reviews.values.toList(),
          issues: curation.issues.values.toList(),
        );
        final dq = const CityQualityService().calculateScore(
          pack: pack,
          dbStats: stats,
          manualQa: qa,
        );
        final tr = const TravelReadinessService().calculateScore(
          pack: pack,
          dbStats: stats,
        );
        final media = await const MediaIntegrityService().validate(
          city,
          excluded: curation.exclusions.keys.toSet(),
          overrides: {
            for (final e in curation.overrides.entries)
              if (e.value.primaryImagePath != null)
                e.key: e.value.primaryImagePath!,
          },
        );
        final gate = const ReleaseGateService().evaluate(
          pack: pack,
          dbStats: stats,
          dataQuality: dq,
          travelReadiness: tr,
          manualQa: qa,
          reviewCandidates: manifest.candidates,
          inboxDecisions: decisions,
          reviewManifestProblem: manifest.warnings.isEmpty
              ? manifest.error
              : manifest.warnings.join(' '),
          mediaIntegrityBlockers: media,
        );
        debugPrint(
          'OPERATIONAL AUDIT ${jsonEncode({'city': city, 'dq': dq.overallScore, 'tr': tr.overallScore, 'qa': qa.reviewedCount, 'pass': qa.approvedCount, 'issues': qa.issueCount, 'research': qa.uncertainCount, 'status': gate.displayStatus, 'blockers': gate.criticalBlockers, 'evaluation_ms': watch.elapsedMilliseconds})}',
        );
        expect(gate.isBlocked, isTrue);
        expect(qa.reviewedCount, lessThan(50));
        if (city != 'jaipur') expect(qa.displayStatus, 'NOT_STARTED');
      } finally {
        await db.close();
      }
    }
  });
}
