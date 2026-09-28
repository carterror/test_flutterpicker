import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import 'dom_probe_model.dart';

/// Drives a raw `<input type="file">` to find out whether the browser still
/// delivers the `change` event once the input has been detached from the DOM.
///
/// This deliberately mirrors `WebFileInputSession.start()` from
/// `file_picker_web` 4.0.0:
///
/// ```dart
/// target.children.add(uploadInput);
/// uploadInput.click();
/// _clearTargetChildren();   // <- the input leaves the document here
/// ```
///
/// When [detachImmediately] is `false` the input is kept in the document until
/// the probe finishes. That single difference is the whole experiment.
///
/// The `window` `focus` listener is installed in both modes because
/// `FilePickerWebOptions.cancelUploadOnWindowBlur` defaults to `true`, which is
/// how `file_picker_web` turns "no `change` event" into "resolve with `null`".
Future<DomProbeReport> runInputProbe({
  required String mode,
  required bool detachImmediately,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  final Completer<DomProbeReport> completer = Completer<DomProbeReport>();

  final Element host = _probeHost();
  final HTMLInputElement input = HTMLInputElement()
    ..type = 'file'
    ..style.display = 'none';

  // Declared before `settle` so it can reference them; assigned as soon as the
  // closures below are built. `toJS` creates a new JS function on every call,
  // so each one is created exactly once and reused for add/removeEventListener.
  late final JSFunction onChange;
  late final JSFunction onCancel;
  late final JSFunction onWindowFocus;

  bool settled = false;

  void settle(DomProbeOutcome outcome, {int fileCount = 0, String? fileName}) {
    if (settled) return;
    settled = true;

    input.removeEventListener('change', onChange);
    input.removeEventListener('cancel', onCancel);
    window.removeEventListener('focus', onWindowFocus);

    if (!completer.isCompleted) {
      completer.complete(
        DomProbeReport(
          mode: mode,
          outcome: outcome,
          elapsed: stopwatch.elapsed,
          fileCount: fileCount,
          fileName: fileName,
        ),
      );
    }
  }

  onChange = ((Event _) {
    final FileList? files = input.files;
    final File? first = (files != null && files.length > 0)
        ? files.item(0)
        : null;
    settle(
      DomProbeOutcome.changeFired,
      fileCount: files?.length ?? 0,
      fileName: first?.name,
    );
  }).toJS;

  onCancel = ((Event _) {
    settle(DomProbeOutcome.cancelEvent);
  }).toJS;

  onWindowFocus = ((Event _) {
    // Mirrors the `cancelUploadOnWindowBlur` grace period: if the selection has
    // not arrived by now, it never will.
    Future<void>.delayed(
      const Duration(milliseconds: 500),
      () => settle(DomProbeOutcome.windowRefocusedNoChange),
    );
  }).toJS;

  input.addEventListener('change', onChange);
  input.addEventListener('cancel', onCancel);
  window.addEventListener('focus', onWindowFocus);

  host.children.add(input);
  input.click();

  if (detachImmediately) {
    // Exactly what `_clearTargetChildren()` does in file_picker_web 4.0.0.
    input.parentNode?.removeChild(input);
  }

  final Timer safety = Timer(timeout, () => settle(DomProbeOutcome.timedOut));

  final DomProbeReport report = await completer.future;
  safety.cancel();
  stopwatch.stop();

  // Leave no trace behind, whichever mode was used.
  input.parentNode?.removeChild(input);

  return report;
}

/// User agent reported by the current browser.
String browserUserAgent() => window.navigator.userAgent;

/// Best-effort engine detection, used to label the report.
bool isLikelyWebKit() {
  final String ua = window.navigator.userAgent.toLowerCase();

  // Every browser on iOS is WebKit, even when it reports Chrome or Edge.
  final bool isIOS =
      ua.contains('iphone') ||
      ua.contains('ipad') ||
      (ua.contains('macintosh') && ua.contains('mobile'));
  if (isIOS) return true;

  final bool isBlink =
      ua.contains('chrome') || ua.contains('chromium') || ua.contains('edg/');
  return ua.contains('applewebkit') && ua.contains('safari') && !isBlink;
}

/// Returns the container the probe attaches its input to, creating it if needed.
Element _probeHost() {
  Element? host = document.querySelector('#dom-probe-host');
  if (host == null) {
    host = document.createElement('div')..id = 'dom-probe-host';
    final Element? body = document.body;
    body?.appendChild(host);
  }
  return host;
}
