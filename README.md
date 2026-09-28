# file_picker #2222 — minimal reproduction

Reproduction project for
[vicajilau/flutter_file_picker#2222](https://github.com/vicajilau/flutter_file_picker/issues/2222)
("Not working for Safari/Chrome on macOS/iOS").

On Apple platforms, choosing a file in the browser dialog leaves
`FilePicker.pickFile()` / `FilePicker.pickFiles()` unresolved: the future either
never completes, or completes with `null` even though a file **was** selected.
The same code works in Chrome on Windows/Android.

This repo contains two things:

1. **A minimal repro of the reported behaviour**, written against the current
   public API (`file_picker: ^13.1.0`) and nothing else.
2. **An isolated DOM probe** that reproduces the *mechanism* with no
   `file_picker` code involved, so the suspected cause can be confirmed or
   ruled out in one click.

## Versions

| Package | Version |
| --- | --- |
| `file_picker` | 13.1.0 |
| `file_picker_web` | 4.0.0 |
| `file_picker_platform_interface` | 4.0.0 |
| Flutter / Dart | see `flutter --version` |

Browsers reported: Safari and Chrome on macOS, and browsers on iOS.

Section **4. Environment** in the running app prints the exact user agent, so a
result can be tied to a specific browser build.

## Run it

```sh
flutter pub get
flutter run -d chrome
```

To test Safari, build for web and serve the output:

```sh
flutter build web
python -m http.server 8080 --directory build/web
# then open http://localhost:8080 in Safari
```

## Repro steps

> Section **0. Upload field** is the same `FilePicker.pickFile()` call wrapped
> in an ordinary upload field, so the failure can be seen where a user would hit
> it. It is a real picker call, not a mock.

1. Open the app in Safari on macOS (or any browser on iOS).
2. Under **1. Repro with the real plugin**, click *pickFile — as in the issue*.
3. Choose any file in the system dialog and confirm.
4. Repeat for the other two variants.

**Expected:** the log shows `✓ resolved with "<name>"` within milliseconds and
the pending banner disappears.

**Observed:** the pending banner keeps counting up
(`still pending after 30.0 s…`) and the call either never resolves, or resolves
with `⚠ resolved with NULL — a file was chosen but never arrived`.

## The isolated DOM probe

Section **2** drives a bare `<input type="file">` via `package:web`, bypassing
`file_picker` entirely. The two buttons are identical except for one line.

| Button | Behaviour |
| --- | --- |
| *input kept in DOM* | The input stays in the document until the browser answers. |
| *input detached* | The input is removed from the document right after `click()`. |

Recorded baseline on Chromium/Windows — the platform where the bug does **not**
occur. This is what the instrument reports when nothing is wrong:

| Probe | Result |
| --- | --- |
| *input kept in DOM* | `change event received — the selection reached Dart` |
| *input detached* | `change event received — the selection reached Dart` |

Note the second row: **on Chromium, detaching the input does not stop the
`change` event.** Detaching is therefore not universally fatal — at most it is
engine-specific, and the WebKit reading is what actually decides it.

What to look for on Apple hardware:

- **kept in DOM** → `change event received — the selection reached Dart`
- **detached** → `window regained focus with NO change event` (which the plugin
  turns into `null`) or `nothing happened before the timeout` (the plugin hangs)

If the **detached** probe reports `change event received` on Safari/iOS too, the
candidate below is wrong and the cause lies elsewhere.

## Candidate cause (unconfirmed)

`WebFileInputSession.start()` in `file_picker_web` 4.0.0 detaches the file input
from the document immediately after clicking it:

```dart
_clearTargetChildren();
target.children.add(uploadInput);
uploadInput.click();
_clearTargetChildren();   // <- the input leaves the document here
return _completer.future;
```

The input is therefore **not in the document for the entire time the native
picker is open**. `_completer` is only completed from the input's `change`
listener, so if that event never arrives the future never resolves.

This also accounts for the two different symptoms reported:

- `FilePickerWebOptions.cancelUploadOnWindowBlur` defaults to `true`, so a
  `focus` listener is registered. When the dialog closes the window is focused
  again and `_onCancel` completes the future with `null` after a 500 ms grace
  period → *"returns null"*.
- Where the window never really regains focus (an iOS picker is an in-window
  sheet rather than a separate window), nothing completes the future at all →
  *"hangs indefinitely"*.

### Related API gap

The `webOptions` parameter of the public API takes `WebOptions`, which is an
empty class:

```dart
class WebOptions {
  const WebOptions();
}
```

The type that actually carries the options — `FilePickerWebOptions`, with
`cancelUploadOnWindowBlur`, `withData`, `withReadStream`, `readSequential` — is
declared in `file_picker_web` and is **not** re-exported from
`package:file_picker/file_picker.dart`. So the defaults always apply and there is
no public way to opt out of the focus heuristic.

### If it is confirmed, a possible fix

Keep the input attached until the interaction is finished, and detach it in the
completion paths instead (`_onFileSelection`, `_onCancel`, and the timeout):

```dart
_clearTargetChildren();
target.children.add(uploadInput);
uploadInput.click();
// Do NOT detach here: an input that is removed while the OS dialog is open
// does not deliver `change` on every engine.
return _completer.future;
```

## Status

Verified here (Chromium/Windows, `flutter build web` output served on
localhost):

- ✅ Static analysis clean (`flutter analyze`) and widget smoke test passing.
- ✅ `FilePicker.pickFile()` resolves with the file name when a file is chosen.
- ✅ `FilePicker.pickFile()` resolves with `null` when the dialog is dismissed.
- ✅ Both DOM probe modes deliver the `change` event — i.e. the suspected detach
  issue does **not** reproduce on Chromium, matching the report that
  Windows/Android work.

Not verified:

- ⚠️ **No Apple result yet.** The Safari/macOS and iOS readings are the missing
  piece; they are the reason the probe exists. Nothing above should be read as
  confirming the candidate cause.

## Layout

| File | Purpose |
| --- | --- |
| `lib/main.dart` | The repro page: plugin calls, live log, environment banner. |
| `lib/dom_probe.dart` | Platform-safe entry point (conditional export). |
| `lib/dom_probe_web.dart` | The real `<input type="file">` probe. |
| `lib/dom_probe_stub.dart` | No-op stub so non-web builds and tests still compile. |
| `lib/dom_probe_model.dart` | Shared result types. |
