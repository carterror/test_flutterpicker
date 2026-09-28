// Smoke test: the reproduction page renders.
//
// The interesting behaviour only happens in a real browser, so this just guards
// the widget tree. Note that `dom_probe.dart` resolves to its non-web stub here,
// which is what lets `flutter test` run on the Dart VM at all.

import 'package:flutter_test/flutter_test.dart';

import 'package:test_flutterpicker/main.dart';

void main() {
  testWidgets('repro page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('1. Repro with the real plugin'), findsOneWidget);
    expect(find.text('pickFile — as in the issue'), findsOneWidget);
  });
}
