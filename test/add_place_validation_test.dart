import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatracanvas_citypack_lab/domain/curation/place_addition.dart';
import 'package:yatracanvas_citypack_lab/widgets/curation/add_place_wizard_dialog.dart';

void main() {
  testWidgets(
    'new-place wizard requires actual coordinates and evidence; hours stay unknown',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      PlaceAddition? added;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddPlaceWizardDialog.show(
                  context,
                  cityId: 'fixture',
                  bbox: {
                    'min_lat': 26.8,
                    'max_lat': 27.1,
                    'min_lon': 75.7,
                    'max_lon': 76.0,
                  },
                  onAdd: (p) => added = p,
                ),
                child: const Text('Add fixture'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add fixture'));
      await tester.pumpAndSettle();
      Future<void> next() async {
        await tester.tap(
          find.textContaining(RegExp(r'^continue$', caseSensitive: false)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> back() async {
        await tester.tap(
          find.textContaining(RegExp(r'^cancel$', caseSensitive: false)),
        );
        await tester.pumpAndSettle();
      }

      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await next();
      expect(find.text('Please enter place name'), findsOneWidget);
      await tester.enterText(
        field('Place Name (English)*'),
        'Regression Garden',
      );
      await next();
      expect(
        tester.widget<TextField>(field('Latitude (WGS84)*')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(field('Longitude (WGS84)*')).controller!.text,
        isEmpty,
      );
      await tester.enterText(field('Latitude (WGS84)*'), '91');
      await tester.enterText(field('Longitude (WGS84)*'), '75.8');
      await next();
      await next();
      await next();
      await next();
      expect(added, isNull);
      expect(find.text('Enter valid latitude and longitude.'), findsOneWidget);
      await back();
      await back();
      await back();
      await tester.enterText(field('Latitude (WGS84)*'), '26.9');
      await next();
      await next();
      await next();
      await next();
      expect(added, isNull);
      expect(
        find.text('Add source evidence for this new place.'),
        findsOneWidget,
      );
      await back();
      await back();
      expect(
        tester.widget<TextField>(field('Opening Hours')).controller!.text,
        isEmpty,
      );
      await tester.enterText(
        field('Evidence / Source Link*'),
        'Synthetic UI regression evidence',
      );
      await next();
      await next();
      await next();
      expect(added?.latitude, 26.9);
      expect(added?.openingHours, isNull);
      expect(added?.primaryImagePath, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
