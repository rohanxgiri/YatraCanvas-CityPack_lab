import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yatracanvas_citypack_lab/domain/curation/curated_place.dart';
import 'package:yatracanvas_citypack_lab/domain/lab_place.dart';
import 'package:yatracanvas_citypack_lab/widgets/curation/image_curator_dialog.dart';

void main() {
  final place = CuratedPlace(
    rawPlace: const LabPlace(
      id: 'amber_fort',
      cityId: 'jaipur',
      name: 'Amber Fort',
      latitude: 26.9855,
      longitude: 75.8513,
      category: 'attraction',
      tier: 'core_destination',
      travelRelevanceScore: 0.95,
      prominenceScore: 0.95,
    ),
  );

  testWidgets(
    'AC-1 and AC-5: selects and imports a photo without rebuilding a closing dialog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = img.Image(width: 800, height: 600)
        ..clear(img.ColorRgb8(31, 106, 92));
      final sourceBytes = img.encodePng(source);
      ImageImportSelection? imported;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ImageCuratorDialog(
                      place: place,
                      pickFile: () async => ImageFileSelection(
                        filename: 'amber.png',
                        bytes: sourceBytes,
                      ),
                      onImport: (selection) async {
                        imported = selection;
                      },
                      onSave: ({
                        required primaryImagePath,
                        required evidenceSource,
                      }) async {},
                      onFlag: (_, _) async {},
                    ),
                  ),
                  child: const Text('Open photo curator'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open photo curator'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();

      expect(find.text('amber.png'), findsOneWidget);
      expect(find.bySemanticsLabel('Selected photo preview'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Wikimedia Commons');
      expect(find.text('Photographer or author'), findsNothing);
      await tester.tap(find.text('Import photo'));
      await tester.pumpAndSettle();

      expect(imported?.filename, 'amber.png');
      expect(imported?.source, 'Wikimedia Commons');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows a recoverable error when the file picker fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ImageCuratorDialog(
                  place: place,
                  pickFile: () async => throw Exception('picker failed'),
                  onImport: (_) async {},
                  onSave: ({
                    required primaryImagePath,
                    required evidenceSource,
                  }) async {},
                  onFlag: (_, _) async {},
                ),
              ),
              child: const Text('Open photo curator'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open photo curator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The photo could not be opened'),
      findsOneWidget,
    );
    expect(find.text('Choose photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-1: stays usable in a narrow desktop window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ImageCuratorDialog(
                  place: place,
                  pickFile: () async => null,
                  onImport: (_) async {},
                  onSave: ({
                    required primaryImagePath,
                    required evidenceSource,
                  }) async {},
                  onFlag: (_, _) async {},
                ),
              ),
              child: const Text('Open photo curator'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open photo curator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import photo'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a photo to continue.'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
