# Draft reply for issue #2222

Paste this as a comment on
<https://github.com/vicajilau/flutter_file_picker/issues/2222>, then reopen the
issue. Everything here is limited to what is actually verifiable — no claim is
made that the bug was reproduced on Apple hardware.

---

Thanks for the pointer about the API — you are right, my snippet was written
against the pre-12 API and does not compile against 13.1.0. Here is the same
call in the current API, and a minimal project that isolates what I am seeing.

**Minimal repro:** https://github.com/carterror/test_flutterpicker

It is a web-only Flutter app with two parts:

1. Buttons that call `FilePicker.pickFile()` / `pickFiles()` with the current
   API, plus a live log showing whether and when the future resolves.
2. An isolated DOM probe that drives a bare `<input type="file">` through
   `package:web`, with no `file_picker` code involved.

### Why the probe

I could not run your macOS setup, so I went looking for the mechanism in
`file_picker_web` 4.0.0 and found one candidate in
`lib/src/web_file_input_session.dart`:

```dart
_clearTargetChildren();
target.children.add(uploadInput);
uploadInput.click();
_clearTargetChildren();   // <- input leaves the document here
return _completer.future;
```

The input is detached from the document immediately after `click()`, so it is
**not in the DOM for the whole time the OS dialog is open**. `_completer` is
only completed from that input's `change` listener.

Two things follow that match the two symptoms in my report:

- `FilePickerWebOptions.cancelUploadOnWindowBlur` defaults to `true`, which
  registers a `window` `focus` listener. When the dialog closes and focus
  returns, `_onCancel` completes the future with `null` after 500 ms — the
  "resolves with null" case.
- Where the window never actually regains focus (an iOS picker is an in-window
  sheet, not a separate window), nothing completes the future — the "hangs
  indefinitely" case.

The probe compares "input kept in DOM" against "input detached right after
click()" with otherwise identical code, so this is one click to confirm or
dismiss on your hardware.

**I already ran it on Chromium/Windows, where the bug does not occur, and both
modes delivered the `change` event.** So detaching is *not* universally fatal.
That is consistent with the report that Windows/Android are fine, but it means
this candidate only holds if WebKit behaves differently — and that is the reading
I cannot take from here:

| Probe | Chromium (Windows) | Safari (macOS) / iOS |
| --- | --- | --- |
| input kept in DOM | `change` received | ? |
| input detached | `change` received | ? |

Also verified in the same run: `FilePicker.pickFile()` resolves correctly with
the file name on Chromium, and with `null` when the dialog is dismissed. So the
app exercises the real code paths rather than just the probe.

### Also worth a look

`WebOptions` — the type accepted by the public `webOptions:` parameter — is an
empty class, while the type that carries the real options
(`FilePickerWebOptions`: `cancelUploadOnWindowBlur`, `withData`,
`withReadStream`, `readSequential`) lives in `file_picker_web` and is not
re-exported from `package:file_picker/file_picker.dart`. So those defaults are
not overridable from the documented API, which makes the focus heuristic hard to
rule out from user code.

What I cannot do from here is take the WebKit reading, which is the one that
decides this. If it helps, I am happy to test any proposed patch on macOS/iOS
and report back with the probe output.
