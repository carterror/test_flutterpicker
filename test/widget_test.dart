// Smoke test: the reproduction page renders.
//
// The interesting behaviour only happens in a real browser, so this just guards
// the widget tree. Note that `dom_probe.dart` resolves to its non-web stub here,
// which is what lets `flutter test` run on the Dart VM at all.

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:test_flutterpicker/main.dart';

void main() {
  testWidgets('repro page renders', (WidgetTester tester) async {
    // Widen the surface so every card is laid out, since ListView builds lazily.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());

    expect(find.text('0. Upload field (simulated preview)'), findsOneWidget);
    expect(find.text('Simulate a selection'), findsOneWidget);
    expect(find.text('1. Repro with the real plugin'), findsOneWidget);
    expect(find.text('pickFile — as in the issue'), findsOneWidget);
  });

  testWidgets('simulated field adds and removes fabricated files', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());

    expect(
      find.text('No files yet — press "Simulate a selection".'),
      findsOneWidget,
    );

    await tester.tap(find.text('Simulate a selection'));
    await tester.pumpAndSettle();
    expect(find.text('informe-final.pdf'), findsOneWidget);

    await tester.tap(find.text('Simulate a selection'));
    await tester.pumpAndSettle();
    expect(find.text('captura-pantalla.png'), findsOneWidget);

    // Removing the first fabricated file leaves the second in place.
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('informe-final.pdf'), findsNothing);
    expect(find.text('captura-pantalla.png'), findsOneWidget);
  });
}
