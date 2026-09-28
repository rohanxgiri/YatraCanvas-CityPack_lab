import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yatracanvas_citypack_lab/domain/city_pack.dart';
import 'package:yatracanvas_citypack_lab/qa/qa_export_service.dart';
import 'package:yatracanvas_citypack_lab/quality/models/data_quality_score.dart';
import 'package:yatracanvas_citypack_lab/quality/models/manual_qa_summary.dart';
import 'package:yatracanvas_citypack_lab/quality/models/release_gate_result.dart';
import 'package:yatracanvas_citypack_lab/quality/models/travel_readiness_score.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('release_evidence_test_');
    QaExportService.setOverrideDirectory(tempDir);
  });

  tearDown(() {
    QaExportService.setOverrideDirectory(null);
    tempDir.deleteSync(recursive: true);
  });

  test('READY evidence is machine readable and certified', () async {
    // covers: AC-1
    final artifacts = await QaExportService().exportCertifiedRelease(
      pack: _pack,
      dataQuality: _dataQuality,
      travelReadiness: _travelReadiness,
      releaseGate: _readyGate,
      manualQa: _sufficientQa,
    );

    final release =
        jsonDecode(artifacts['release.json']!) as Map<String, dynamic>;
    expect(release['schema_version'], 1);
    expect(release['city_id'], 'jaipur');
    expect(release['pack_version'], 'v8');
    expect(release['status'], 'certified');
    expect(release['release_gate_status'], 'READY');
    expect(release['manual_qa_passed'], isTrue);
    expect(release['certified_at'], isNotNull);
  });

  test(
    'blocked evidence is never labelled or timestamped as certified',
    () async {
      // covers: AC-2, AC-8
      final artifacts = await QaExportService().exportCertifiedRelease(
        pack: _pack,
        dataQuality: _dataQuality,
        travelReadiness: _travelReadiness,
        releaseGate: const ReleaseGateResult(
          status: ReleaseStatus.blocked,
          criticalBlockers: ['Manual QA incomplete'],
          warnings: [],
          checks: {'manual_qa': false},
          timestamp: '2026-09-28T10:00:00Z',
        ),
        manualQa: const ManualQaSummary(
          state: ManualQaState.notStarted,
          reviewedCount: 0,
          minimumRequired: 50,
          approvedCount: 0,
          issueCount: 0,
          uncertainCount: 0,
        ),
      );

      final release =
          jsonDecode(artifacts['release.json']!) as Map<String, dynamic>;
      expect(release['status'], 'not_certified');
      expect(release['release_gate_status'], 'BLOCKED');
      expect(release['manual_qa_passed'], isFalse);
      expect(release['certified_at'], isNull);
      expect(release['certifiedAt'], isNull);
    },
  );
}

const _pack = CityPack(
  id: 'jaipur',
  name: 'Jaipur',
  state: 'Rajasthan',
  country: 'India',
  version: 'v8',
  placeCount: 100,
  imageCount: 80,
  dbSizeMb: 1,
  integrityStatus: IntegrityStatus.pass,
  centerLat: 26.9,
  centerLon: 75.8,
  minLat: 26.7,
  minLon: 75.6,
  maxLat: 27.1,
  maxLon: 76,
);

const _dataQuality = DataQualityScore(
  overallScore: 92,
  dimensions: {},
  summary: 'Ready',
);

const _travelReadiness = TravelReadinessScore(
  overallScore: 94,
  dimensions: {},
  warnings: [],
  summary: 'Ready',
);

const _readyGate = ReleaseGateResult(
  status: ReleaseStatus.ready,
  criticalBlockers: [],
  warnings: [],
  checks: {'manual_qa': true},
  timestamp: '2026-09-28T10:00:00Z',
);

const _sufficientQa = ManualQaSummary(
  state: ManualQaState.sufficientSample,
  reviewedCount: 50,
  minimumRequired: 50,
  approvedCount: 48,
  issueCount: 2,
  uncertainCount: 0,
  score: .96,
);
