/// Minimal reproduction for
/// https://github.com/vicajilau/flutter_file_picker/issues/2222
///
/// "Not working for Safari/Chrome on macOS/iOS": choosing a file in the browser
/// dialog leaves `FilePicker.pickFile()` / `pickFiles()` unresolved.
///
/// This is a web-only project. Run it with:
///
/// ```sh
/// flutter run -d chrome
/// ```
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'dom_probe.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'file_picker #2222 repro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const ReproPage(),
    );
  }
}

/// One entry of the on-screen event log.
class _LogEntry {
  _LogEntry(this.message, {required this.at});

  final String message;

  /// Timestamp relative to the start of the call that produced it.
  final Duration at;
}

class ReproPage extends StatefulWidget {
  const ReproPage({super.key});

  @override
  State<ReproPage> createState() => _ReproPageState();
}

class _ReproPageState extends State<ReproPage> {
  final List<_LogEntry> _entries = <_LogEntry>[];
  Timer? _ticker;

  String? _pickerLabel;
  Stopwatch? _pickerWatch;

  String? _probeLabel;
  Stopwatch? _probeWatch;

  DomProbeReport? _attachedReport;
  DomProbeReport? _detachedReport;

  bool get _busy => _pickerLabel != null || _probeLabel != null;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Keeps a 100 ms ticker alive so pending calls visibly keep counting up.
  void _ensureTicking() {
    _ticker ??= Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );
  }

  void _stopTickingIfIdle() {
    if (!_busy) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _log(String message, {Duration at = Duration.zero}) {
    _entries.insert(0, _LogEntry(message, at: at));
  }

  /// Runs a picker call and reports how long it took — or keeps the UI at
  /// "still pending" forever when the future never resolves.
  Future<void> _callPicker({
    required String label,
    required Future<String> Function() action,
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    setState(() {
      _pickerLabel = label;
      _pickerWatch = watch;
      _log('▸ $label');
    });
    _ensureTicking();

    String summary;
    try {
      summary = await action();
    } catch (error) {
      summary = '✗ threw ${error.runtimeType}: $error';
    }
    watch.stop();

    if (!mounted) return;
    setState(() {
      _pickerLabel = null;
      _pickerWatch = null;
      _log('$summary   [${watch.elapsedMilliseconds} ms]', at: watch.elapsed);
    });
    _stopTickingIfIdle();
  }

  // Variant 1: the call as written in the issue. Note that `type` defaults to
  // `FileType.any`, so `allowedExtensions` is ignored on the web and no
  // `accept` attribute is applied.
  Future<void> _pickAsReported() => _callPicker(
    label: 'pickFile(allowedExtensions: [pdf, png, jpg])  — as in the issue',
    action: () async {
      final PlatformFile? file = await FilePicker.pickFile(
        allowedExtensions: <String>['pdf', 'png', 'jpg'],
      );
      return file == null
          ? '⚠ resolved with NULL — a file was chosen but never arrived'
          : '✓ resolved with "${file.name}"';
    },
  );

  // Variant 2: the same call with an explicit custom type, so the `accept`
  // attribute is actually populated.
  Future<void> _pickWithCustomType() => _callPicker(
    label:
        'pickFile(type: FileType.custom, allowedExtensions: [pdf, png, jpg])',
    action: () async {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: <String>['pdf', 'png', 'jpg'],
      );
      return file == null
          ? '⚠ resolved with NULL — a file was chosen but never arrived'
          : '✓ resolved with "${file.name}"';
    },
  );

  // Variant 3: multiple selection.
  Future<void> _pickMultiple() => _callPicker(
    label: 'pickFiles(type: FileType.any)',
    action: () async {
      final List<PlatformFile> files = await FilePicker.pickFiles();
      return files.isEmpty
          ? '⚠ resolved with an EMPTY list — a file was chosen but never arrived'
          : '✓ resolved with ${files.length} file(s): '
                '${files.map((PlatformFile f) => f.name).join(', ')}';
    },
  );

  Future<void> _runProbe({required bool detach}) async {
    final String label = detach
        ? 'input removed from the DOM right after click()'
        : 'input kept in the DOM until the browser answers';
    final Stopwatch watch = Stopwatch()..start();
    setState(() {
      _probeLabel = label;
      _probeWatch = watch;
    });
    _ensureTicking();

    DomProbeReport report;
    try {
      report = await runInputProbe(mode: label, detachImmediately: detach);
    } catch (error) {
      report = DomProbeReport(
        mode: label,
        outcome: DomProbeOutcome.error,
        elapsed: watch.elapsed,
        detail: '$error',
      );
    }
    watch.stop();

    if (!mounted) return;
    setState(() {
      _probeLabel = null;
      _probeWatch = null;
      if (detach) {
        _detachedReport = report;
      } else {
        _attachedReport = report;
      }
    });
    _stopTickingIfIdle();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text(
          'file_picker #2222 — picker never resolves on Apple web',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _Card(
                title: '1. Repro with the real plugin',
                subtitle:
                    'Click a button, choose a file in the dialog and confirm. '
                    'If the log stays at "still pending…", the future never '
                    'resolved.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton(
                          onPressed: _busy ? null : _pickAsReported,
                          child: const Text('pickFile — as in the issue'),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : _pickWithCustomType,
                          child: const Text('pickFile — FileType.custom'),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : _pickMultiple,
                          child: const Text('pickFiles — multiple'),
                        ),
                      ],
                    ),
                    if (_pickerLabel != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _PendingBanner(
                        label: _pickerLabel!,
                        elapsed: _pickerWatch?.elapsed ?? Duration.zero,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Card(
                title: '2. Isolated DOM probe (no file_picker involved)',
                subtitle:
                    'Proves the mechanism: a bare <input type="file"> that is '
                    'detached right after click() — exactly what '
                    'file_picker_web 4.0.0 does — against the same input kept '
                    'in the DOM. Run both and compare.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _runProbe(detach: false),
                          child: const Text('Run probe — input kept in DOM'),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _runProbe(detach: true),
                          child: const Text('Run probe — input detached'),
                        ),
                      ],
                    ),
                    if (_probeLabel != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _PendingBanner(
                        label: _probeLabel!,
                        elapsed: _probeWatch?.elapsed ?? Duration.zero,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ProbeRow(
                      title: 'input kept in the DOM',
                      report: _attachedReport,
                      expectedToWork: true,
                    ),
                    _ProbeRow(
                      title: 'input detached after click()',
                      report: _detachedReport,
                      expectedToWork: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Card(
                title: '3. Log',
                subtitle: 'Newest first. Times are measured in Dart.',
                child: _entries.isEmpty
                    ? Text(
                        'Nothing yet — run one of the buttons above.',
                        style: theme.textTheme.bodySmall,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final _LogEntry entry in _entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${entry.at.inMilliseconds.toString().padLeft(6)} ms  ${entry.message}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              const _EnvironmentCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.label, required this.elapsed});

  final String label;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.error),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label — still pending after '
            '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)} s…',
            style: TextStyle(color: colors.error, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ProbeRow extends StatelessWidget {
  const _ProbeRow({
    required this.title,
    required this.report,
    required this.expectedToWork,
  });

  final String title;
  final DomProbeReport? report;

  /// Whether this mode is supposed to deliver the selection.
  final bool expectedToWork;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final DomProbeReport? value = report;
    final String? detail = value?.detail;

    final Color tone = value == null
        ? colors.onSurfaceVariant
        : value.selectionReceived
        ? colors.primary
        : colors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            value == null
                ? Icons.help_outline
                : value.selectionReceived
                ? Icons.check_circle_outline
                : Icons.error_outline,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${expectedToWork ? 'expected: works' : 'expected: reproduces the bug'} · $title',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value == null
                      ? 'not run yet'
                      : '${_describeOutcome(value.outcome)}  '
                            '[${value.elapsed.inMilliseconds} ms]',
                  style: theme.textTheme.bodySmall?.copyWith(color: tone),
                ),
                if (detail != null)
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return _Card(
      title: '4. Environment',
      subtitle: 'Include this when reporting.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(browserUserAgent(), style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            'kIsWeb: $kIsWeb\n'
            'engine looks like WebKit: ${isLikelyWebKit()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _describeOutcome(DomProbeOutcome outcome) => switch (outcome) {
  DomProbeOutcome.changeFired =>
    'change event received — the selection reached Dart',
  DomProbeOutcome.cancelEvent => 'the browser fired cancel',
  DomProbeOutcome.windowRefocusedNoChange =>
    'window regained focus with NO change event → plugin resolves with null',
  DomProbeOutcome.timedOut =>
    'nothing happened before the timeout → plugin hangs forever',
  DomProbeOutcome.error => 'the probe threw',
  DomProbeOutcome.unsupported => 'not available outside the web target',
};
