import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatracanvas_citypack_lab/app/app_state.dart';
import 'package:yatracanvas_citypack_lab/domain/qa_issue.dart';
import 'package:yatracanvas_citypack_lab/screens/city_pack_screen.dart';
import 'package:yatracanvas_citypack_lab/screens/search_screen.dart';
import 'package:yatracanvas_citypack_lab/screens/place_detail_screen.dart';
import 'package:yatracanvas_citypack_lab/screens/test_trip_screen.dart';
import 'package:yatracanvas_citypack_lab/data/city_pack_loader.dart';
import 'package:yatracanvas_citypack_lab/qa/qa_export_service.dart';
import 'package:yatracanvas_citypack_lab/qa/qa_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = createDatabaseFactoryFfi(noIsolate: true);

  late Directory tempTestDir;
  late AppState state;

  setUpAll(() async {
    tempTestDir = Directory.systemTemp.createTempSync('widget_flow_test_');
    QaRepository.setOverrideDirectory(tempTestDir);
    CityPackLoader.setOverrideDirectory(tempTestDir);
    QaExportService.setOverrideDirectory(tempTestDir);
    state = AppState();
    await state.loadPacks();
    final manaliPack = state.availablePacks.firstWhere((p) => p.id == 'manali');
    await state.openPack(manaliPack);
  });

  tearDownAll(() async {
    try {
      await state.repository?.database.db.close();
    } catch (_) {}
    try {
      if (tempTestDir.existsSync()) {
        tempTestDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('Full Lab Flow: Pack -> Search -> Details -> Trip -> Report -> Export',
      (WidgetTester tester) async {
    expect(state.availablePacks.isNotEmpty, isTrue);
    expect(state.activePack?.id, 'manali');
    expect(state.repository, isNotNull);

    // 1. Render CityPackScreen
    await tester.pumpWidget(
      MaterialApp(
        home: CityPackScreen(state: state),
      ),
    );
    await tester.pump();

    expect(find.text('Gulmarg'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Manali'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Manali'), findsOneWidget);

    // 2. Search "cafe"
    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(state: state),
      ),
    );
    await tester.pump();

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    // Perform query via state in runAsync
    final results = await tester.runAsync(() async {
      return await state.repository!.search(query: 'cafe', limit: 10);
    });
    expect(results != null && results.isNotEmpty, isTrue);
    final cafePlace = results!.first;

    // 3. Add to Test Trip
    await tester.runAsync(() async {
      await state.addPlaceToTrip(cafePlace.id);
    });
    expect(state.tripSelection!.contains(cafePlace.id), isTrue);

    // 4. Open Place Detail Screen
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceDetailScreen(place: cafePlace, state: state),
      ),
    );
    await tester.pump();

    expect(find.text(cafePlace.name), findsWidgets);
    expect(find.text('In Test Trip'), findsOneWidget);

    // 5. Report Problem
    final issue = QaIssue(
      id: 'widget_flow_issue_1',
      timestamp: DateTime.now().toIso8601String(),
      cityId: 'manali',
      packVersion: 'v3',
      placeId: cafePlace.id,
      placeName: cafePlace.name,
      tier: cafePlace.tier,
      category: cafePlace.category,
      latitude: cafePlace.latitude,
      longitude: cafePlace.longitude,
      issueType: QaIssueType.wrongCategory,
      note: 'Tested from automated widget flow',
    );
    await tester.runAsync(() async {
      await state.reportIssue(issue);
    });

    expect(state.currentSession!.issues.any((i) => i.id == 'widget_flow_issue_1'), isTrue);

    // 6. Verify in Test Trip Screen
    await tester.pumpWidget(
      MaterialApp(
        home: TestTripScreen(state: state),
      ),
    );
    await tester.pump();
    expect(find.text('Test Trip Basket'), findsOneWidget);

    // 7. Export QA Session
    final export = await tester.runAsync(() async {
      return await state.exportQaReport();
    });
    expect(export, isNotNull);
    expect(export!.jsonContent, contains('widget_flow_issue_1'));
    expect(export.mdContent, contains('Manali'));
    expect(File(export.jsonFilePath).existsSync(), isTrue);
    expect(File(export.mdFilePath).existsSync(), isTrue);
  });
}
