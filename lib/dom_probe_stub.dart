import 'dom_probe_model.dart';

/// Non-web stub: the DOM probe only makes sense inside a browser.
///
/// Having a stub keeps the project compilable for every target and lets
/// `flutter test` run on the Dart VM where `package:web` is unavailable.
Future<DomProbeReport> runInputProbe({
  required String mode,
  required bool detachImmediately,
  Duration timeout = const Duration(seconds: 20),
}) async {
  return DomProbeReport(
    mode: mode,
    outcome: DomProbeOutcome.unsupported,
    elapsed: Duration.zero,
    detail: 'This probe only runs on the web target.',
  );
}

/// User agent of the current browser, or a placeholder off the web.
String browserUserAgent() => 'not available (not running on the web)';

/// Whether the current browser is suspected to use the WebKit engine.
bool isLikelyWebKit() => false;
