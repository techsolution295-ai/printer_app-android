import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import '../l10n/labels.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import '../ads/ad_service.dart';
import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snack.dart';
import '../widgets/pro_crown_icon.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key, required this.images});

  final List<PlatformFile> images;

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  late List<PlatformFile> _images;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _images = List<PlatformFile>.from(widget.images);
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    for (final img in _images) {
      if (img.path == null) continue;
      final bytes = await File(img.path!).readAsBytes();
      final mem = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Image(mem, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    return doc.save();
  }

  Future<void> _savePdf() async {
    if (_images.isEmpty) {
      _show(t(context, 'select_images_first'));
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdf();
      if (bytes.isEmpty) {
        throw StateError('Generated PDF is empty.');
      }
      final Directory dir;
      if (Platform.isAndroid) {
        final external = await getExternalStorageDirectory();
        dir = external ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      await dir.create(recursive: true);
      final file = File(
        '${dir.path}/images_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Image to PDF',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: _images.length,
        ),
      );
      if (!mounted) return;
      _show(t(context, 'saved_to_files'));
    } catch (error) {
      debugPrint('Image to PDF save failed: $error');
      if (mounted) _show(t(context, 'could_not_save_pdf', namedArgs: {'error': '$error'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPdf() async {
    if (_images.isEmpty) {
      _show(t(context, 'select_images_first'));
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdf();
      if (bytes.isEmpty) {
        throw StateError('Generated PDF is empty.');
      }
      final Directory dir;
      if (Platform.isAndroid) {
        final external = await getExternalStorageDirectory();
        dir = external ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      await dir.create(recursive: true);
      final file = File(
        '${dir.path}/images_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Image to PDF (Print)',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: _images.length,
        ),
      );
      if (!mounted) return;
      await openPrintLayout(name: 'images_to_pdf.pdf', bytes: bytes);
      if (!mounted) return;
    } catch (error) {
      debugPrint('Image to PDF print failed: $error');
      if (mounted) _show(t(context, 'could_not_print_pdf', namedArgs: {'error': '$error'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    AppSnack.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return AppBusyOverlay(
      busy: _busy,
      message: t(context, 'please_wait'),
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF2B3A55),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t(context, 'feat_image_to_pdf'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B3A55),
          ),
        ),
        actions: const [
          ProAppBarButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: _HeaderCard(count: _images.length),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _images.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _images.removeAt(oldIndex);
                  _images.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final file = _images[index];
                return _ImageTile(
                  key: ValueKey(file.path ?? index),
                  title: t(context, 'image_n', namedArgs: {'n': '${index + 1}'}),
                  subtitle: file.name,
                  thumb: _ImageThumb(path: file.path),
                );
              },
            ),
          ),
          _BottomActions(
            busy: _busy,
            onSave: afterInterstitial(_savePdf),
            onPrint: afterInterstitial(_printPdf),
          ),
        ],
      ),
    ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppTheme.actionColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(context, 'images_count', namedArgs: {'count': '$count'}),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2B3A55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.thumb,
  });

  final String title;
  final String subtitle;
  final Widget thumb;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(height: 52, width: 52, child: thumb),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8BA6),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.drag_handle_rounded,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty || !File(path!).existsSync()) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.photo_rounded,
          color: Color(0xFF94A3B8),
          size: 18,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path!),
        fit: BoxFit.cover,
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.busy,
    required this.onSave,
    required this.onPrint,
  });

  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onSave,
                icon: const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  t(context, 'save'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B3A55),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: busy ? null : onPrint,
                icon: const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  busy ? t(context, 'working') : t(context, 'print'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.actionColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
