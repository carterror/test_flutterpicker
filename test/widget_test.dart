// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:test_flutterpicker/main.dart';

void main() {
  testWidgets('File upload field renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // The upload field and its hint are visible before any file is picked.
    expect(find.byType(FileUploadField), findsOneWidget);
    expect(find.text('Selecciona uno o varios archivos'), findsOneWidget);
    expect(find.text('Quitar todos'), findsNothing);
  });
}
