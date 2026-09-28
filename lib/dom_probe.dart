/// Platform-safe entry point for the isolated DOM probe.
///
/// On the web the real implementation (which drives a raw
/// `<input type="file">` through `package:web`) is used. On every other
/// platform a stub is substituted, so the project still compiles everywhere
/// and `flutter test` keeps working on the Dart VM.
library;

export 'dom_probe_model.dart';
export 'dom_probe_stub.dart' if (dart.library.js_interop) 'dom_probe_web.dart';
