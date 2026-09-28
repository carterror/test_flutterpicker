// Smoke tests for the reproduction page.
//
// The interesting behaviour only happens in a real browser, so these guard the
// widget tree and the field's failure handling instead. Note that
// `dom_probe.dart` resolves to its non-web stub here, which is what lets
// `flutter test` run on the Dart VM at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_flutterpicker/main.dart';

/// Widens the surface so every card is laid out, since ListView builds lazily.
void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('repro page renders', (WidgetTester tester) async {
    _useLargeSurface(tester);

    await tester.pumpWidget(const MyApp());

    expect(find.text('0. Upload field'), findsOneWidget);
    expect(find.text('Upload a file'), findsOneWidget);
    expect(find.text('No file selected yet.'), findsOneWidget);
    expect(find.text('1. Repro with the real plugin'), findsOneWidget);
    expect(find.text('pickFile — as in the issue'), findsOneWidget);
  });

  testWidgets('upload field recovers when the picker is unavailable', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);

    await tester.pumpWidget(const MyApp());

    // On the Dart VM there is no platform implementation, so this exercises the
    // failure path: the field must log the problem and return to its idle state
    // rather than staying stuck on "waiting for the picker…".
    await tester.tap(find.text('Upload a file'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('No file selected yet.'), findsOneWidget);
    expect(find.textContaining('upload field →'), findsWidgets);

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Upload a file'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('the page is not a lazy list, so cards keep their state', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);

    await tester.pumpWidget(const MyApp());

    // A ListView would dispose cards once they scroll out of view, which
    // silently discards the file picked in the upload field. Keep it non-lazy.
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
