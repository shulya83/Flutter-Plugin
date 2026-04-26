import 'package:flutter_test/flutter_test.dart';

import 'package:win_text_overlay_demo/app.dart';

void main() {
  testWidgets('renders the Windows focus dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DemoApp());

    expect(find.text('Windows Text Overlay Demo'), findsOneWidget);
    expect(find.text('Focused App'), findsOneWidget);
    expect(find.text('Focused Control'), findsOneWidget);
    expect(find.text('Text Extraction'), findsOneWidget);
  });
}
