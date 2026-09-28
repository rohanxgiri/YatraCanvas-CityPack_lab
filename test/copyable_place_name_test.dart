import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatracanvas_citypack_lab/widgets/curation/copyable_place_name.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('place name and address can be selected with a pointer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CopyablePlaceName(
            name: 'Nahargarh Wildlife Sanctuary',
            address: 'Jaipur, Rajasthan',
          ),
        ),
      ),
    );

    expect(
      find.widgetWithText(SelectableText, 'Nahargarh Wildlife Sanctuary'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(SelectableText, 'Jaipur, Rajasthan'),
      findsOneWidget,
    );
  });

  testWidgets('copy button writes the place name to the clipboard', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CopyablePlaceName(name: 'Nahargarh Wildlife Sanctuary'),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy name'));
    await tester.pump();

    expect(copiedText, 'Nahargarh Wildlife Sanctuary');
    expect(find.text('Copied "Nahargarh Wildlife Sanctuary"'), findsOneWidget);
  });
}
