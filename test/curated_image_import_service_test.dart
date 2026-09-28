import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:yatracanvas_citypack_lab/curation/curated_image_import_service.dart';

void main() {
  late Directory workspace;
  late CuratedImageImportService service;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('citypack_media_test_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString(
      'name: media_test\r\nflutter:\r\n  assets:\r\n    - assets/city_packs/\r\n',
    );
    service = CuratedImageImportService(
      workspaceRoot: workspace,
      now: () => DateTime.utc(2026, 9, 27, 12, 30),
    );
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  test(
    'AC-3 and AC-4: creates WebP variants and a complete provenance record',
    () async {
      final source = img.Image(width: 2200, height: 1400)
        ..clear(img.ColorRgb8(31, 106, 92));
      final sourceBytes = img.encodeJpg(source, quality: 90);

      final result = await service.importImage(
        cityId: 'jaipur',
        placeId: 'hawa_mahal',
        sourceBytes: sourceBytes,
        originalFilename: 'Hawa Mahal.jpg',
        source: 'Wikimedia Commons',
        sourcePage: 'https://commons.wikimedia.org/example',
        license: 'CC BY-SA 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
        contributor: 'qa-user',
      );

      expect(result.primaryImagePath, 'images/hawa_mahal/primary.webp');
      expect(result.thumbnailImagePath, 'images/hawa_mahal/thumbnail.webp');
      expect(result.width, 1600);
      expect(result.height, lessThan(1600));

      final imageRoot = p.join(
        workspace.path,
        'assets',
        'city_packs',
        'jaipur',
        'images',
        'hawa_mahal',
      );
      final primaryBytes = await File(p.join(imageRoot, 'primary.webp'))
          .readAsBytes();
      final thumbnailBytes = await File(p.join(imageRoot, 'thumbnail.webp'))
          .readAsBytes();
      final primary = img.decodeWebP(primaryBytes);
      final thumbnail = img.decodeWebP(thumbnailBytes);
      expect(primary, isNotNull);
      expect(primary!.width, 1600);
      expect(thumbnail, isNotNull);
      expect(thumbnail!.width, 480);

      final metadataFile = File(
        p.join(
          workspace.path,
          'assets',
          'city_packs',
          'jaipur',
          'curation',
          'media',
          'hawa_mahal.json',
        ),
      );
      final metadata =
          jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
      expect(metadata['schemaVersion'], 1);
      expect(metadata['author'], '');
      expect(metadata['contributor'], 'qa-user');
      expect(metadata['importedAt'], '2026-09-27T12:30:00.000Z');
      expect(metadata['originalSha256'], hasLength(64));
    },
  );

  test(
    'AC-2: rejects an unreadable file before creating pack output',
    () async {
      expect(
        () => service.importImage(
          cityId: 'jaipur',
          placeId: 'bad_file',
          sourceBytes: utf8.encode('not an image'),
          originalFilename: 'bad.jpg',
          source: 'Contributor',
          sourcePage: '',
          license: 'Contributor owned',
          licenseUrl: '',
          contributor: 'qa-user',
        ),
        throwsA(
          isA<ImageImportException>().having(
            (error) => error.message,
            'message',
            contains('not a readable'),
          ),
        ),
      );

      final output = Directory(
        p.join(
          workspace.path,
          'assets',
          'city_packs',
          'jaipur',
          'images',
          'bad_file',
        ),
      );
      expect(await output.exists(), isFalse);
    },
  );

  test('AC-2: rejects an image below the minimum resolution', () async {
    final small = img.Image(width: 500, height: 300)
      ..clear(img.ColorRgb8(20, 20, 20));

    expect(
      () => service.importImage(
        cityId: 'jaipur',
        placeId: 'small_image',
        sourceBytes: img.encodePng(small),
        originalFilename: 'small.png',
        source: 'Contributor',
        sourcePage: '',
        license: 'Contributor owned',
        licenseUrl: '',
        contributor: 'qa-user',
      ),
      throwsA(
        isA<ImageImportException>().having(
          (error) => error.message,
          'message',
          contains('at least 640 × 480'),
        ),
      ),
    );
  });

  test('AC-7: registers a generated asset directory only once', () async {
    final source = img.Image(width: 800, height: 600)
      ..clear(img.ColorRgb8(227, 154, 50));
    Future<ImportedPlaceImage> request() => service.importImage(
      cityId: 'jaipur',
      placeId: 'amber_fort',
      sourceBytes: img.encodePng(source),
      originalFilename: 'amber.png',
      source: 'Contributor',
      sourcePage: '',
      license: 'Contributor owned',
      licenseUrl: '',
      contributor: 'qa-user',
    );

    await request();
    await request();

    final pubspec = await File(p.join(workspace.path, 'pubspec.yaml'))
        .readAsString();
    final matches = RegExp('assets/city_packs/jaipur/images/amber_fort/')
        .allMatches(pubspec);
    expect(matches.length, 1);
    expect(pubspec, contains('\r\n'));
    expect(RegExp(r'(?<!\r)\n').hasMatch(pubspec), isFalse);
  });
}
