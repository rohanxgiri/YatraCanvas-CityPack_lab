import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatracanvas_citypack_lab/domain/lab_place.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/curated_place.dart';
import 'package:yatracanvas_citypack_lab/widgets/curation/opening_hours_editor_dialog.dart';

void main() {
  final place = CuratedPlace(
    rawPlace: const LabPlace(
      id: 'fixture',
      cityId: 'city',
      name: 'Fixture',
      latitude: 26.9,
      longitude: 75.8,
      category: 'heritage',
      tier: 'recommended',
      travelRelevanceScore: 0,
      prominenceScore: 0,
    ),
  );
  Future<void> open(
    WidgetTester tester,
    Function({required String openingHours, required String evidenceSource})
    save,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => OpeningHoursEditorDialog.show(
                ctx,
                place: place,
                onSave: save,
              ),
              child: const Text('Edit hours'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit hours'));
    await tester.pumpAndSettle();
  }

  testWidgets('missing hours remain unknown without invented defaults', (
    tester,
  ) async {
    String? saved;
    await open(
      tester,
      ({required openingHours, required evidenceSource}) =>
          saved = openingHours,
    );
    await tester.tap(find.text('Save Correction'));
    await tester.pumpAndSettle();
    expect(saved, '');
  });
  testWidgets('verified weekly split intervals require source evidence', (
    tester,
  ) async {
    String? saved, source;
    await open(tester, ({required openingHours, required evidenceSource}) {
      saved = openingHours;
      source = evidenceSource;
    });
    await tester.tap(find.text('Edit a weekly schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      '11:00-14:00,17:00-22:00',
    );
    await tester.tap(find.text('I verified this schedule against the source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Correction'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(
      find.text('Verified hours require a schedule and source evidence.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField).last,
      'Official venue notice, fixture only',
    );
    await tester.tap(find.text('Save Correction'));
    await tester.pumpAndSettle();
    expect(saved, contains('Mo 11:00-14:00,17:00-22:00'));
    expect(saved, contains('Tu unknown'));
    expect(source, startsWith('Verified hours:'));
  });
  testWidgets('invalid weekly time rejected before save', (tester) async {
    String? saved;
    await open(
      tester,
      ({required openingHours, required evidenceSource}) =>
          saved = openingHours,
    );
    await tester.tap(find.text('Edit a weekly schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '25:00-27:00');
    await tester.tap(find.text('Save Correction'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(
      find.text('Use HH:mm-HH:mm intervals, Closed, Unknown, or 24 hours.'),
      findsOneWidget,
    );
  });
}
