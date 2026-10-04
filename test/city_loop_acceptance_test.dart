import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_repository.dart';
import 'package:yatracanvas_citypack_lab/curation/curation_service.dart';
import 'package:yatracanvas_citypack_lab/curation/curated_image_import_service.dart';
import 'package:yatracanvas_citypack_lab/domain/lab_place.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/curated_place.dart';
import 'package:yatracanvas_citypack_lab/widgets/curation/place_editor_dialog.dart';
import 'package:yatracanvas_citypack_lab/widgets/curation/image_curator_dialog.dart';

void main() {
  const acceptance = bool.fromEnvironment('CITY_LOOP_ACCEPTANCE');
  testWidgets(
    'actual place editor and photo curator persist an exportable repair',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final root = acceptance
          ? Directory('artifacts/offline-acceptance-01').absolute
          : (await tester.runAsync(
              () => Directory.systemTemp.createTemp('lab-loop-'),
            ))!;
      await tester.runAsync(() async {
        await root.create(recursive: true);
        await File('${root.path}/pubspec.yaml').writeAsString(
          'name: lab_test\nflutter:\n  assets:\n    - assets/city_packs/\n',
        );
        if (acceptance) {
          await Directory('${root.path}/assets/city_packs/jaipur')
              .create(recursive: true);
          for (final name in ['yatracanvas.db', 'lab_sync_receipt.json']) {
            await File('assets/city_packs/jaipur/$name')
                .copy('${root.path}/assets/city_packs/jaipur/$name');
          }
        }
      });
      final fixture = jsonDecode(
        (await tester.runAsync(
          () => File('test/fixtures/city_loop_acceptance.json').readAsString(),
        ))!,
      ) as Map<String, dynamic>;
      final pid = fixture['place_id'] as String;
      sqfliteFfiInit();
      final db = (await tester.runAsync(
        () => createDatabaseFactoryFfi(noIsolate: true).openDatabase(
          File('assets/city_packs/jaipur/yatracanvas.db').absolute.path,
          options: OpenDatabaseOptions(readOnly: true),
        ),
      ))!;
      final row = (await tester.runAsync(
        () => db.query('places', where: 'id = ?', whereArgs: [pid]),
      ))!.single;
      final raw = LabPlace.fromMap(row);
      await tester.runAsync(() => db.close());
      CurationRepository.setOverrideDirectory(
        Directory('${root.path}/assets/city_packs'),
      );
      addTearDown(() async {
        CurationRepository.setOverrideDirectory(null);
        if (!acceptance) {
          await tester.runAsync(() => root.delete(recursive: true));
        }
      });
      final service = CurationService(
        currentContributor: 'City loop acceptance QA',
      )..sourcePackVersion = fixture['source_version'] as String;
      await tester.runAsync(() => service.loadCityCuration('jaipur'));
      if (acceptance) {
        expect(
          service.overrides.containsKey(pid),
          isFalse,
          reason: 'Preserve existing human work; acceptance uses an unedited record',
        );
      }
      Future<void>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PlaceEditorDialog.show(
                  context,
                  place: CuratedPlace(rawPlace: raw),
                  onSave:
                      ({
                        required name,
                        nameHi,
                        description,
                        website,
                        phone,
                        tier,
                        required evidenceSource,
                      }) {
                        saved = tester.runAsync(
                          () => service.saveFieldOverride(
                            place: raw,
                            name: name,
                            nameHi: nameHi,
                            description: description,
                            website: website,
                            phone: phone,
                            tier: tier,
                            fieldName: 'description',
                            evidenceSource: evidenceSource,
                          ),
                        );
                      },
                ),
                child: const Text('Edit record'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit record'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(2),
        fixture['description'] as String,
      );
      await tester.tap(find.text('Save Details'));
      await tester.pumpAndSettle();
      await saved;
      expect(service.overrides[pid]?.description, fixture['description']);
      final photo = (await tester.runAsync(
        () => File(fixture['image_file'] as String).readAsBytes(),
      ))!;
      final importer = CuratedImageImportService(workspaceRoot: root);
      Future<void>? importDone;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ImageCuratorDialog(
                    place: CuratedPlace(rawPlace: raw),
                    pickFile: () async => ImageFileSelection(
                      bytes: photo,
                      filename: 'suraj_pol_qa.webp',
                    ),
                    onImport: (selection) {
                      importDone = tester.runAsync(() async {
                        final image = await importer.importImage(
                          cityId: 'jaipur',
                          placeId: pid,
                          sourceBytes: selection.bytes,
                          originalFilename: selection.filename,
                          source: selection.source,
                          sourcePage: selection.sourcePage,
                          license: selection.license,
                          licenseUrl: selection.licenseUrl,
                          contributor: 'City loop acceptance QA',
                        );
                        await service.saveFieldOverride(
                          place: raw,
                          primaryImagePath: image.primaryImagePath,
                          fieldName: 'media',
                          evidenceSource: 'Existing exact-identity test photograph, local testing only',
                        );
                      });
                      return importDone!;
                    },
                    onSave: ({
                      required primaryImagePath,
                      required evidenceSource,
                    }) async {},
                    onFlag: (_, _) async {},
                  ),
                ),
                child: const Text('Import real photo'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import real photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'JaipurThruMyLens');
      await tester.enterText(
        find.byType(TextField).at(1),
        fixture['source_page'] as String,
      );
      await tester.tap(
        find.text('This is a real photograph of this exact place'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UNVERIFIED_TEST_ONLY').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import photo'));
      await importDone;
      await tester.pumpAndSettle();
      expect(service.overrides[pid]?.primaryImagePath, isNotNull);
      expect(tester.takeException(), isNull);
      final reload = CurationService();
      await tester.runAsync(() => reload.loadCityCuration('jaipur'));
      expect(reload.overrides[pid]?.description, fixture['description']);
      final meta = jsonDecode(
        (await tester.runAsync(
          () => File(
            '${root.path}/assets/city_packs/jaipur/curation/media/$pid.json',
          ).readAsString(),
        ))!,
      ) as Map;
      expect(meta['mediaClass'], 'TEST_ONLY_REAL');
      expect(meta['countsTowardSourceReadiness'], isFalse);
    },
  );
}
