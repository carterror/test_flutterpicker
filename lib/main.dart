// An example demonstrating the usage of file_picker.
import 'dart:ui' show PathMetric;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Picker Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const FileUploadPage(),
    );
  }
}

class FileUploadPage extends StatelessWidget {
  const FileUploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Subir un archivo'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: FileUploadField(
              label: 'Archivo adjunto',
              helperText:
                  'Haz clic en el recuadro para seleccionar uno o varios '
                  'archivos (PDF, PNG o JPG).',
              allowedExtensions: <String>['pdf', 'png', 'jpg'],
            ),
          ),
        ),
      ),
    );
  }
}

/// A form-style field that lets the user pick one or more files.
///
/// It renders a dashed drop zone that opens the native file picker on tap and
/// lists the current selection below it.
class FileUploadField extends StatefulWidget {
  const FileUploadField({
    super.key,
    this.label,
    this.helperText,
    this.allowedExtensions,
    this.allowMultiple = true,
    this.onChanged,
  });

  /// Optional label rendered above the field.
  final String? label;

  /// Optional helper text rendered below the field.
  final String? helperText;

  /// When non-empty, restricts the picker to these extensions (without dots).
  final List<String>? allowedExtensions;

  /// Whether the user can pick more than one file.
  final bool allowMultiple;

  /// Called whenever the selection changes.
  final ValueChanged<List<PlatformFile>>? onChanged;

  @override
  State<FileUploadField> createState() => _FileUploadFieldState();
}

class _FileUploadFieldState extends State<FileUploadField> {
  final List<_PickedFile> _files = <_PickedFile>[];
  bool _isPicking = false;

  bool get _hasExtensions => widget.allowedExtensions?.isNotEmpty ?? false;

  Future<void> _pick() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final FileType type = _hasExtensions ? FileType.custom : FileType.any;
      final String dialogTitle = widget.label ?? 'Selecciona un archivo';

      final List<PlatformFile> picked;
      if (widget.allowMultiple) {
        picked = await FilePicker.pickFiles(
          dialogTitle: dialogTitle,
          type: type,
          allowedExtensions: widget.allowedExtensions,
        );
      } else {
        final PlatformFile? file = await FilePicker.pickFile(
          dialogTitle: dialogTitle,
          type: type,
          allowedExtensions: widget.allowedExtensions,
        );
        picked = file == null ? const <PlatformFile>[] : <PlatformFile>[file];
      }

      // An empty result means the user canceled the dialog.
      if (picked.isEmpty) return;

      final resolved = <_PickedFile>[];
      for (final PlatformFile file in picked) {
        final int? size = file.lengthSync() ?? await file.length();
        resolved.add(_PickedFile(file, size));
      }

      if (!mounted) return;
      setState(() {
        if (widget.allowMultiple) {
          _files.addAll(resolved);
        } else {
          _files
            ..clear()
            ..add(resolved.first);
        }
      });
      _notify();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar el archivo: $error')),
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _remove(_PickedFile entry) {
    setState(() => _files.remove(entry));
    _notify();
  }

  void _clear() {
    setState(_files.clear);
    _notify();
  }

  void _notify() {
    widget.onChanged?.call(
      List<PlatformFile>.unmodifiable(_files.map((e) => e.file)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            widget.label!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _DropZone(
          enabled: !_isPicking,
          onTap: _pick,
          child: _isPicking
              ? const _PickerLoading()
              : _DropZoneHint(
                  allowMultiple: widget.allowMultiple,
                  extensions: widget.allowedExtensions,
                ),
        ),
        if (widget.helperText != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            widget.helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        if (_files.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          for (final _PickedFile entry in _files)
            _FileTile(entry: entry, onRemove: () => _remove(entry)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Quitar todos'),
            ),
          ),
        ],
      ],
    );
  }
}

/// A tappable rectangle with a dashed border.
class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.child,
    required this.onTap,
    required this.enabled,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: enabled ? colors.outline : colors.outlineVariant,
          radius: 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 20,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropZoneHint extends StatelessWidget {
  const _DropZoneHint({required this.allowMultiple, this.extensions});

  final bool allowMultiple;
  final List<String>? extensions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool hasExtensions = extensions?.isNotEmpty ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.cloud_upload_outlined, size: 40, color: colors.primary),
        const SizedBox(height: 12),
        Text(
          allowMultiple
              ? 'Selecciona uno o varios archivos'
              : 'Selecciona un archivo',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          hasExtensions
              ? 'Formatos: ${extensions!.map((e) => e.toUpperCase()).join(', ')}'
              : 'Cualquier tipo de archivo',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PickerLoading extends StatelessWidget {
  const _PickerLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 88,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.entry, required this.onRemove});

  final _PickedFile entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final PlatformFile file = entry.file;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFor(file.extension),
              size: 22,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Quitar',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// A picked file together with its resolved size in bytes.
class _PickedFile {
  const _PickedFile(this.file, this.size);

  final PlatformFile file;
  final int? size;

  String get subtitle {
    final List<String> parts = <String>[
      if (size case final int bytes) _formatBytes(bytes),
      if (file.extension case final String ext) ext.toUpperCase(),
    ];
    return parts.join(' · ');
  }
}

/// Paints a dashed rounded border around the widget it decorates.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  static const double _dash = 6;
  static const double _gap = 4;
  static const double _strokeWidth = 1.5;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final Rect rect = Rect.fromLTWH(
      _strokeWidth / 2,
      _strokeWidth / 2,
      size.width - _strokeWidth,
      size.height - _strokeWidth,
    );
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}

IconData _iconFor(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
      return Icons.image_outlined;
    case 'doc':
    case 'docx':
      return Icons.description_outlined;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart_outlined;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip_outlined;
    case 'mp4':
    case 'mov':
    case 'avi':
      return Icons.movie_outlined;
    case 'mp3':
    case 'wav':
      return Icons.audiotrack_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}
