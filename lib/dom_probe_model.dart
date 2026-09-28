/// Shared, platform-independent model for the isolated DOM probe.
///
/// This lives in its own file so that both the web implementation and the
/// non-web stub can depend on it without creating an import cycle.
library;

/// What the browser did after the hidden `<input type="file">` was clicked.
enum DomProbeOutcome {
  /// The browser delivered a `change` event: the selection reached Dart.
  changeFired,

  /// The browser fired the (non-standard) `cancel` event.
  cancelEvent,

  /// The window regained focus without a `change` event ever arriving.
  ///
  /// This is the signature of the `cancelUploadOnWindowBlur` heuristic in
  /// `file_picker_web`, which completes the pending future with `null` once
  /// the window is focused again.
  windowRefocusedNoChange,

  /// Nothing happened at all before the safety timeout elapsed.
  ///
  /// This is the "hangs indefinitely" half of the reported symptom.
  timedOut,

  /// The probe itself threw.
  error,

  /// The probe is only meaningful on the web target.
  unsupported,
}

/// The result of driving a raw `<input type="file">` directly, bypassing
/// `file_picker` entirely.
class DomProbeReport {
  const DomProbeReport({
    required this.mode,
    required this.outcome,
    required this.elapsed,
    this.fileCount = 0,
    this.fileName,
    this.detail,
  });

  /// Human readable description of the mode that produced this report.
  final String mode;

  /// What the browser did.
  final DomProbeOutcome outcome;

  /// Time between `input.click()` and the browser's response.
  final Duration elapsed;

  /// How many files the browser handed over, when it handed any over.
  final int fileCount;

  /// Name of the first selected file, when available.
  final String? fileName;

  /// Optional extra context, usually an error message.
  final String? detail;

  /// Whether the selected file actually reached Dart.
  bool get selectionReceived => outcome == DomProbeOutcome.changeFired;
}
