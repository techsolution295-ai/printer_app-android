import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_snack.dart';

class TextPreScreen extends StatefulWidget {
  const TextPreScreen({super.key, this.initialText});

  final String? initialText;

  @override
  State<TextPreScreen> createState() => _TextPreScreenState();
}

class _TextPreScreenState extends State<TextPreScreen> {
  late final TextEditingController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  Future<Directory> _getSaveDir() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<Uint8List> _saveTextPdf(String text) async {
    final bytes = await _buildPdfFromText(text);
    if (bytes.isEmpty) {
      throw StateError('Generated PDF is empty.');
    }
    final dir = await _getSaveDir();
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}/text_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await HistoryDB.instance.insertHistory(
      PrintHistory(
        title: 'Smart Text',
        type: 'pdf',
        filePath: file.path,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    return bytes;
  }

  Future<void> _saveNow() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _show('Please enter some text.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _saveTextPdf(text);
      if (!mounted) return;
      _show('Saved to Files');
    } catch (error) {
      debugPrint('Smart Text save failed: $error');
      if (mounted) {
        _show('Could not save text: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _printNow() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _show('Please enter some text.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _saveTextPdf(text);
      await Printing.layoutPdf(
        name: 'smart_text.pdf',
        onLayout: (_) async => bytes,
      ).timeout(const Duration(seconds: 20)).catchError((error) {
        debugPrint('Smart Text print dialog failed: $error');
        return false;
      });
      if (!mounted) return;
    } catch (error) {
      debugPrint('Smart Text print failed: $error');
      if (mounted) {
        _show('Could not print/save text: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _show(String message) {
    AppSnack.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
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
          "Smart Text",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B3A55),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2B3A55),
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  hintText: "Type or paste your text here to print...",
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: _busy
                  ? const SizedBox(
                      height: 56,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saveNow,
                            icon: const Icon(Icons.save_rounded, size: 20),
                            label: const Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2B3A55),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _printNow,
                            icon: const Icon(Icons.print_rounded, size: 20),
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
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
