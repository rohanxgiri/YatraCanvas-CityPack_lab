import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/city_pack.dart';
import '../domain/qa_session.dart';

class QaExportResult {
  final String jsonFilePath;
  final String mdFilePath;
  final String jsonContent;
  final String mdContent;

  QaExportResult({
    required this.jsonFilePath,
    required this.mdFilePath,
    required this.jsonContent,
    required this.mdContent,
  });
}

class QaExportService {
  static const String labVersion = '1.0.0';
  static Directory? _overrideExportDir;

  static void setOverrideDirectory(Directory? dir) {
    _overrideExportDir = dir;
  }

  Future<QaExportResult> exportReport({
    required CityPack pack,
    required QaSession session,
    Map<String, dynamic>? qualityStats,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    Directory? exportDir;
    if (!kIsWeb) {
      if (_overrideExportDir != null) {
        exportDir = Directory(p.join(_overrideExportDir!.path, 'qa_exports'));
      } else {
        try {
          final docs = await getApplicationDocumentsDirectory();
          exportDir = Directory(p.join(docs.path, 'qa_exports'));
        } catch (_) {
          exportDir = Directory(
            p.join(Directory.systemTemp.path, 'qa_exports'),
          );
        }
      }

      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }
    }

    // 1. Generate JSON
    final Map<String, dynamic> reportJson = {
      'lab_version': labVersion,
      'exported_at': now.toIso8601String(),
      'city_pack': {
        'id': pack.id,
        'name': pack.name,
        'state': pack.state,
        'country': pack.country,
        'version': pack.version,
        'place_count': pack.placeCount,
        'image_count': pack.imageCount,
        'db_size_mb': pack.dbSizeMb,
        'integrity_status': pack.integrityStatus.name,
        'bbox': [pack.minLon, pack.minLat, pack.maxLon, pack.maxLat],
        'center': [pack.centerLat, pack.centerLon],
      },
      'quality_stats': qualityStats ?? {},
      'session_meta': {
        'created_at': session.createdAt,
        'last_modified': session.lastModified,
      },
      'issues': session.issues.map((e) => e.toJson()).toList(),
      'random_reviews': session.randomReviews.map((e) => e.toJson()).toList(),
      'search_reviews': session.searchReviews.map((e) => e.toJson()).toList(),
      'expected_place_checks': session.expectedPlaceChecks
          .map((e) => e.toJson())
          .toList(),
      'scenario_results': session.scenarioResults
          .map((e) => e.toJson())
          .toList(),
      'trip_selections_count': session.tripSelections.length,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(reportJson);
    String jsonPath = 'in_browser_memory';
    if (!kIsWeb && exportDir != null) {
      final jsonFile = File(
        p.join(exportDir.path, 'qa_${pack.id}_$dateStr.json'),
      );
      await jsonFile.writeAsString(jsonStr, flush: true);
      jsonPath = jsonFile.path;
    }

    // 2. Generate Markdown
    final mdBuf = StringBuffer();
    mdBuf.writeln('# YatraCanvas City Pack QA Report: ${pack.name}');
    mdBuf.writeln();
    mdBuf.writeln('- **City**: ${pack.name} (${pack.state}, ${pack.country})');
    mdBuf.writeln('- **Pack ID**: `${pack.id}`');
    mdBuf.writeln('- **Pack Version**: `${pack.version}`');
    mdBuf.writeln(
      '- **Integrity**: `${pack.integrityStatus.name.toUpperCase()}`',
    );
    mdBuf.writeln('- **Export Date**: ${now.toIso8601String()}');
    mdBuf.writeln('- **Lab Version**: `$labVersion`');
    mdBuf.writeln();

    mdBuf.writeln('## 1. Summary Metrics');
    mdBuf.writeln();
    mdBuf.writeln('| Metric | Value |');
    mdBuf.writeln('|---|---|');
    mdBuf.writeln('| Total Pack Places | ${pack.placeCount} |');
    mdBuf.writeln('| Total Pack Images | ${pack.imageCount} |');
    mdBuf.writeln('| Database Size | ${pack.dbSizeMb} MB |');
    mdBuf.writeln('| Total QA Issues Logged | ${session.issues.length} |');
    mdBuf.writeln(
      '| Random Reviews Completed | ${session.randomReviews.length} |',
    );
    mdBuf.writeln(
      '| Search Queries Reviewed | ${session.searchReviews.length} |',
    );
    mdBuf.writeln(
      '| Expected Places Checked | ${session.expectedPlaceChecks.length} |',
    );
    mdBuf.writeln('| Test Trip Places | ${session.tripSelections.length} |');
    mdBuf.writeln();

    mdBuf.writeln('## 2. Reported Issues (${session.issues.length})');
    mdBuf.writeln();
    if (session.issues.isEmpty) {
      mdBuf.writeln('*No issues reported.*');
    } else {
      mdBuf.writeln('| ID | Place | Tier | Issue Type | Note | Coordinates |');
      mdBuf.writeln('|---|---|---|---|---|---|');
      for (final i in session.issues) {
        mdBuf.writeln(
          '| `${i.placeId}` | ${i.placeName} | ${i.tier} | **${i.issueType.label}** | ${i.note.replaceAll('\n', ' ')} | `${i.latitude.toStringAsFixed(4)}, ${i.longitude.toStringAsFixed(4)}` |',
        );
      }
    }
    mdBuf.writeln();

    mdBuf.writeln('## 3. Random Reviews (${session.randomReviews.length})');
    mdBuf.writeln();
    if (session.randomReviews.isEmpty) {
      mdBuf.writeln('*No random reviews recorded.*');
    } else {
      final goodCount = session.randomReviews
          .where((r) => r.result == 'looks_good')
          .length;
      final badCount = session.randomReviews.length - goodCount;
      mdBuf.writeln('- **Total Reviewed**: ${session.randomReviews.length}');
      mdBuf.writeln('- **Looks Good**: $goodCount');
      mdBuf.writeln('- **Problems Noted**: $badCount');
      mdBuf.writeln();
      mdBuf.writeln('| Place | Tier | Result | Note |');
      mdBuf.writeln('|---|---|---|---|');
      for (final r in session.randomReviews) {
        final resLabel = r.result == 'looks_good'
            ? '✅ Looks Good'
            : '⚠️ ${r.result}';
        mdBuf.writeln(
          '| ${r.placeName} | ${r.tier} | $resLabel | ${r.note ?? '-'} |',
        );
      }
    }
    mdBuf.writeln();

    mdBuf.writeln(
      '## 4. Expected Place Checks (${session.expectedPlaceChecks.length})',
    );
    mdBuf.writeln();
    if (session.expectedPlaceChecks.isEmpty) {
      mdBuf.writeln('*No expected place checks recorded.*');
    } else {
      mdBuf.writeln('| Search Query | Place Found | Status | Note |');
      mdBuf.writeln('|---|---|---|---|');
      for (final e in session.expectedPlaceChecks) {
        mdBuf.writeln(
          '| ${e.query} | ${e.placeName ?? 'None'} | **${e.status.toUpperCase()}** | ${e.note ?? '-'} |',
        );
      }
    }
    mdBuf.writeln();

    mdBuf.writeln('## 5. Scenario Results (${session.scenarioResults.length})');
    mdBuf.writeln();
    if (session.scenarioResults.isEmpty) {
      mdBuf.writeln('*No scenario tests recorded.*');
    } else {
      for (final s in session.scenarioResults) {
        mdBuf.writeln('### Scenario: ${s.scenarioName}');
        mdBuf.writeln('- **Duration**: ${s.days} days');
        mdBuf.writeln('- **Interests**: ${s.interests.join(', ')}');
        mdBuf.writeln('- **Places Selected**: ${s.selectedPlacesCount}');
        mdBuf.writeln('- **Trust Rating**: **${s.trusted.toUpperCase()}**');
        mdBuf.writeln('- **Notes**: ${s.notes.isEmpty ? 'None' : s.notes}');
        mdBuf.writeln();
      }
    }

    final mdStr = mdBuf.toString();
    String mdPath = 'in_browser_memory';
    if (!kIsWeb && exportDir != null) {
      final mdFile = File(p.join(exportDir.path, 'qa_${pack.id}_$dateStr.md'));
      await mdFile.writeAsString(mdStr, flush: true);
      mdPath = mdFile.path;
    }

    return QaExportResult(
      jsonFilePath: jsonPath,
      mdFilePath: mdPath,
      jsonContent: jsonStr,
      mdContent: mdStr,
    );
  }

  Future<Map<String, String>> exportCertifiedRelease({
    required CityPack pack,
    required dynamic dataQuality, // DataQualityScore
    required dynamic travelReadiness, // TravelReadinessScore
    required dynamic releaseGate, // ReleaseGateResult
    required dynamic manualQa, // ManualQaSummary
    Map<String, dynamic>? dbStats,
    Map<String, dynamic>? reviewState,
  }) async {
    final now = DateTime.now();

    Directory? exportDir;
    if (!kIsWeb) {
      if (_overrideExportDir != null) {
        exportDir = Directory(p.join(_overrideExportDir!.path, 'qa_exports'));
      } else {
        try {
          final docs = await getApplicationDocumentsDirectory();
          exportDir = Directory(p.join(docs.path, 'qa_exports'));
        } catch (_) {
          exportDir = Directory(
            p.join(Directory.systemTemp.path, 'qa_exports'),
          );
        }
      }

      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }
    }

    // 1. release.json
    final isCertified = releaseGate.isReady && manualQa.isSufficient;
    final releaseJsonMap = {
      'schema_version': 1,
      'city_id': pack.id,
      'pack_version': pack.version,
      'status': isCertified ? 'certified' : 'not_certified',
      'release_source': 'citypack_lab',
      'generated_at': now.toUtc().toIso8601String(),
      'certified_at': isCertified ? now.toUtc().toIso8601String() : null,
      'data_quality_score': dataQuality.overallScore,
      'travel_readiness_score': travelReadiness.overallScore,
      'manual_qa_passed':
          releaseGate.checks['manual_qa_sufficient'] ??
          (releaseGate.isReady && manualQa.isSufficient),
      'validation_summary': releaseGate.checks,
      'warning_details': releaseGate.warnings,
      'review_state': reviewState ?? {},
      'manual_qa_reviewed_count': manualQa.reviewedCount,
      'manual_qa_minimum_required': manualQa.minimumRequired,
      'release_gate_status': releaseGate.displayStatus,
      'city': pack.id,
      'pack_name': pack.name,
      'version': pack.version,
      'dataQualityScore': dataQuality.overallScore,
      'travelReadinessScore': travelReadiness.overallScore,
      'manualQaStatus': manualQa.displayStatus,
      'releaseStatus': releaseGate.displayStatus,
      'criticalIssues': releaseGate.criticalBlockers.length,
      'warnings': releaseGate.warnings.length,
      'certifiedAt': isCertified ? now.toUtc().toIso8601String() : null,
    };
    final releaseJsonStr = const JsonEncoder.withIndent('  ')
        .convert(releaseJsonMap);

    // 2. quality_report.json
    final qualityReportMap = {
      'city': pack.id,
      'pack_name': pack.name,
      'version': pack.version,
      'generated_at': now.toIso8601String(),
      'data_quality': dataQuality.toJson(),
      'travel_readiness': travelReadiness.toJson(),
      'manual_qa': manualQa.toJson(),
      'release_gate': releaseGate.toJson(),
      'dataset_stats': dbStats ?? {},
    };
    final qualityReportStr = const JsonEncoder.withIndent('  ')
        .convert(qualityReportMap);

    // 3. release_report.md
    final mdBuf = StringBuffer();
    mdBuf.writeln('# YatraCanvas Release Gate Report: ${pack.name}');
    mdBuf.writeln();
    mdBuf.writeln('**Release Status**: `${releaseGate.displayStatus}`');
    mdBuf.writeln('**Pack Version**: `${pack.version}`');
    mdBuf.writeln('**Date**: `${now.toIso8601String()}`');
    mdBuf.writeln();
    mdBuf.writeln('---');
    mdBuf.writeln();
    mdBuf.writeln('## Executive Scores');
    mdBuf.writeln();
    mdBuf.writeln('| Dimension | Score | Status |');
    mdBuf.writeln('|---|---|---|');
    mdBuf.writeln(
      '| **Data Quality** | **${dataQuality.overallScore} / 100** | ${dataQuality.overallScore >= 70 ? 'PASS' : 'FAIL'} |',
    );
    mdBuf.writeln(
      '| **Travel Readiness** | **${travelReadiness.overallScore} / 100** | ${travelReadiness.overallScore >= 60 ? 'PASS' : 'WARN'} |',
    );
    mdBuf.writeln(
      '| **Manual QA** | ${manualQa.displayStatus} | ${manualQa.isSufficient ? 'PASS' : 'INCOMPLETE'} |',
    );
    mdBuf.writeln();
    mdBuf.writeln('### Release Gate Decision: ${releaseGate.displayStatus}');
    mdBuf.writeln();

    if (releaseGate.criticalBlockers.isNotEmpty) {
      mdBuf.writeln(
        '### Critical Blockers (${releaseGate.criticalBlockers.length})',
      );
      for (final b in releaseGate.criticalBlockers) {
        mdBuf.writeln('- ❌ **$b**');
      }
      mdBuf.writeln();
    } else {
      mdBuf.writeln('✅ **Zero Critical Blockers**');
      mdBuf.writeln();
    }

    if (releaseGate.warnings.isNotEmpty) {
      mdBuf.writeln('### Warnings (${releaseGate.warnings.length})');
      for (final w in releaseGate.warnings) {
        mdBuf.writeln('- ⚠️ $w');
      }
      mdBuf.writeln();
    }

    final mdStr = mdBuf.toString();

    if (!kIsWeb && exportDir != null) {
      await File(p.join(exportDir.path, 'release_${pack.id}.json'))
          .writeAsString(releaseJsonStr, flush: true);
      await File(p.join(exportDir.path, 'quality_report_${pack.id}.json'))
          .writeAsString(qualityReportStr, flush: true);
      await File(p.join(exportDir.path, 'release_report_${pack.id}.md'))
          .writeAsString(mdStr, flush: true);
    }

    return {
      'release.json': releaseJsonStr,
      'quality_report.json': qualityReportStr,
      'release_report.md': mdStr,
    };
  }
}
