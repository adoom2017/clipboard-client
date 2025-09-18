// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:clipboard_auto/main.dart';

void main() {
  testWidgets('Clipboard app basic test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ClipboardApp());

    // Verify that the app bar title is displayed
    expect(find.text('剪贴板监听工具'), findsOneWidget);

    // Verify that empty state message is shown
    expect(find.text('暂无剪贴板记录'), findsOneWidget);
  });
}
