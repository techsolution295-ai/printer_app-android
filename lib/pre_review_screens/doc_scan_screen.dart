import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_snack.dart';

class DocScanScreen extends StatefulWidget {
  const DocScanScreen({super.key});

  @override
  State<DocScanScreen> createState() => _DocScanScreenState();
}

class _DocScanScreenState extends State<DocScanScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isBusy = false;
  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _captureAndScan() async {
    if (kIsWeb) {
      if (!mounted) {
        return;
      }
      AppSnack.show(context, 'OCR is not supported on web.');
      return;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (!mounted) {
        return;
      }
      AppSnack.show(context, 'OCR works only on Android and iOS.');
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _isBusy = true;
      _controller.text = '';
    });

    try {
      final inputImage = InputImage.fromFilePath(picked.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (!mounted) {
        return;
      }
      setState(() {
        _controller.text = recognizedText.text.trim();
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      AppSnack.show(
        context,
        'OCR plugin not loaded. Run flutter pub get and restart.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnack.show(context, 'Failed to scan text.');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<Directory> _getSaveDir() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<Uint8List> _buildPdfFromText(String text) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Paragraph(
            text: text,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _persistScanPdf(String text) async {
    final bytes = await _buildPdfFromText(text);
    if (bytes.isEmpty) {
      throw StateError('Generated PDF is empty.');
    }
    final dir = await _getSaveDir();
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await HistoryDB.instance.insertHistory(
      PrintHistory(
        title: 'Doc Scan',
        type: 'pdf',
        filePath: file.path,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    return bytes;
  }

  Future<void> _saveScan() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      AppSnack.show(context, 'No text to save.');
      return;
    }
    setState(() => _isBusy = true);
    try {
      await _persistScanPdf(text);
      if (!mounted) return;
      AppSnack.show(context, 'Saved to Files');
    } catch (error) {
      debugPrint('Doc scan save failed: $error');
      if (mounted) AppSnack.show(context, 'Could not save scan: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _printText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      AppSnack.show(context, 'No text to print.');
      return;
    }
    setState(() => _isBusy = true);
    try {
      final bytes = await _persistScanPdf(text);
      unawaited(
        Printing.layoutPdf(
          name: 'doc_scan.pdf',
          onLayout: (_) async => bytes,
        ).timeout(const Duration(seconds: 20)).catchError((error) {
          debugPrint('Doc scan print dialog failed: $error');
          return false;
        }),
      );
      if (!mounted) return;
    } catch (error) {
      debugPrint('Doc scan print failed: $error');
      if (mounted) AppSnack.show(context, 'Could not print/save scan: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: const Text(
          'Doc Scanner',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B3A55),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: _ScanHeader(isBusy: _isBusy),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                children: [
                  Expanded(
                    child: _TextCard(
                      controller: _controller,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomActions(
            onSave: _isBusy ? null : _saveScan,
            onCapture: _isBusy ? null : _captureAndScan,
            onPrint: _isBusy ? null : _printText,
          ),
        ],
      ),
    );
  }
}

class _ScanHeader extends StatelessWidget {
  const _ScanHeader({required this.isBusy});

  final bool isBusy;

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
              Icons.document_scanner_rounded,
              color: Color(0xFF2F80ED),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isBusy ? 'Scanning...' : 'Capture a document to extract text',
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

class _TextCard extends StatelessWidget {
  const _TextCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        enabled: false,
        readOnly: true,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2B3A55)),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Scanned text will appear here...',
          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onSave,
    required this.onCapture,
    required this.onPrint,
  });

  final VoidCallback? onSave;
  final VoidCallback? onCapture;
  final VoidCallback? onPrint;

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
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text(
                  'Save',
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
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text(
                  'Scan',
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
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text(
                  'Print',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F80ED),
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
