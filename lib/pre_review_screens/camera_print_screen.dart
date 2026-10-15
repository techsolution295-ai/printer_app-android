import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import '../l10n/labels.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ads/ad_service.dart';
import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snack.dart';
import '../widgets/pro_crown_icon.dart';

class CameraPrintScreen extends StatefulWidget {
  const CameraPrintScreen({super.key, required this.image});

  final XFile image;

  @override
  State<CameraPrintScreen> createState() => _CameraPrintScreenState();
}

class _CameraPrintScreenState extends State<CameraPrintScreen> {
  bool _busy = false;

  XFile get image => widget.image;

  Future<Directory> _getSaveDir() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<Uint8List> _buildPdfFromImage(File file) async {
    final doc = pw.Document();
    final bytes = await file.readAsBytes();
    final mem = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(
          child: pw.Image(mem, fit: pw.BoxFit.contain),
        ),
      ),
    );
    return doc.save();
  }

  Future<void> _saveImage() async {
    if (_busy) return;
    final file = File(image.path);
    if (!file.existsSync()) {
      AppSnack.show(context, t(context, 'image_not_found'));
      return;
    }
    setState(() => _busy = true);
    try {
      final dir = await _getSaveDir();
      await dir.create(recursive: true);
      final folder = Directory(
        '${dir.path}/camera_${DateTime.now().millisecondsSinceEpoch}',
      );
      await folder.create(recursive: true);
      final ext = file.path.split('.').last;
      final target = File('${folder.path}/image_1.$ext');
      await file.copy(target.path);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Camera Print',
          type: 'images',
          filePath: folder.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: 1,
        ),
      );
      if (!mounted) return;
      AppSnack.show(context, t(context, 'saved_to_files'));
    } catch (error) {
      debugPrint('Camera save failed: $error');
      if (mounted) AppSnack.show(context, t(context, 'could_not_save_image'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printImage() async {
    if (_busy) return;
    final file = File(image.path);
    if (!file.existsSync()) {
      AppSnack.show(context, t(context, 'image_not_found'));
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfFromImage(file);
      if (bytes.isEmpty) {
        throw StateError('Generated PDF is empty.');
      }
      final dir = await _getSaveDir();
      await dir.create(recursive: true);
      final pdfFile = File(
        '${dir.path}/camera_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await pdfFile.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Camera Print',
          type: 'pdf',
          filePath: pdfFile.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: 1,
        ),
      );
      if (!mounted) return;
      await openPrintLayout(name: 'camera_print.pdf', bytes: bytes);
    } catch (error) {
      debugPrint('Camera print failed: $error');
      if (mounted) AppSnack.show(context, t(context, 'could_not_print_image'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(image.path);

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
          t(context, 'camera_print'),
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: file.existsSync()
                      ? Image.file(file, fit: BoxFit.contain)
                      : Center(
                          child: Text(
                            t(context, 'image_not_found'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          _BottomActions(
            onPrint: _busy ? null : afterInterstitial(_printImage),
            onSave: _busy ? null : afterInterstitial(_saveImage),
          ),
        ],
      ),
    ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onPrint, required this.onSave});

  final VoidCallback? onPrint;
  final VoidCallback? onSave;

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
                onPressed: onSave,
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
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  t(context, 'print'),
                  style: TextStyle(fontWeight: FontWeight.w700),
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
