import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:yatracanvas_citypack_lab/review/models/review_candidate.dart';
import 'package:yatracanvas_citypack_lab/review/services/review_manifest_loader.dart';
import 'package:yatracanvas_citypack_lab/quality/services/media_integrity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> candidate({
    String tier = 'support',
    String reason = 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
    double confidence = .4,
  }) => {
    'canonical_id': 'fixture',
    'name': 'Fixture',
    'latitude': 26.9,
    'longitude': 75.8,
    'tier': tier,
    'category': 'cafe',
    'confidence': confidence,
    'travel_relevance_reason': reason,
    'review_priority': 'HIGH',
    'travel_relevance_score': .45,
    'missing_fields': ['primary_image', 'description'],
  };
  test('priority follows impact rather than confidence or upstream label', () {
    expect(
      ReviewCandidate.fromJson(candidate()).reviewPriority,
      ReviewPriority.low,
    );
    expect(
      ReviewCandidate.fromJson(candidate(tier: 'recommended')).reviewPriority,
      ReviewPriority.medium,
    );
    expect(
      ReviewCandidate.fromJson(
        candidate(tier: 'recommended', reason: 'CATEGORY_CONFLICT'),
      ).reviewPriority,
      ReviewPriority.high,
    );
    expect(
      ReviewCandidate.fromJson(
        candidate(
          tier: 'core_destination',
          reason: 'IDENTITY_CONFLICT',
          confidence: .78,
        ),
      ).reviewPriority,
      ReviewPriority.blocking,
    );
    expect(
      ReviewCandidate.fromJson(
        candidate(reason: 'IDENTITY_CONFLICT'),
        isPublished: true,
      ).reviewPriority,
      ReviewPriority.blocking,
    );
  });
  test('real selectable Jaipur priorities remain selective and explainable', () async {
    final watch = Stopwatch()..start();
    final result = await ReviewManifestLoader().load('jaipur');
    final counts = {
      for (final priority in ReviewPriority.values)
        priority.label: result.candidates
            .where((c) => c.reviewPriority == priority)
            .length,
    };
    debugPrint(
      'JAIPUR PRIORITIES $counts, conflicts=${result.conflicts.length}, manifest load=${watch.elapsedMilliseconds}ms',
    );
    expect(counts['HIGH']!, lessThan(result.count ~/ 10));
    expect(counts['LOW']!, greaterThan(0));
    expect(counts.values.reduce((a, b) => a + b), 864);
    final raw = jsonDecode(
      await File('assets/city_packs/jaipur/review_candidates.json')
          .readAsString(),
    ) as List;
    expect(raw.length, 893);
    expect(result.conflicts.length, 13);
  });
  test(
    'effective image overrides cannot bypass file or attribution checks',
    () async {
      final root = await Directory.systemTemp.createTemp('citylab_media_test');
      try {
        final base = Directory('${root.path}/assets/city_packs/fixture');
        await Directory('${base.path}/curation/media').create(recursive: true);
        final service = MediaIntegrityService(workspaceRoot: root.path);
        expect(
          await service.validate('fixture', overrides: {'poi': ''}),
          isEmpty,
        );
        expect(
          await service.validate(
            'fixture',
            overrides: {'poi': '../escape.webp'},
          ),
          isNotEmpty,
        );
        await File('${base.path}/primary.webp').writeAsBytes([1]);
        expect(
          await service.validate('fixture', overrides: {'poi': 'primary.webp'}),
          isNotEmpty,
        );
        await File('${base.path}/curation/media/poi.json').writeAsString(
          jsonEncode({
            'primaryImagePath': 'primary.webp',
            'source': 'Own work',
            'author': 'Curator',
            'license': 'CC0',
            'licenseUrl': 'https://creativecommons.org/publicdomain/zero/1.0/',
          }),
        );
        expect(
          await service.validate('fixture', overrides: {'poi': 'primary.webp'}),
          isEmpty,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
