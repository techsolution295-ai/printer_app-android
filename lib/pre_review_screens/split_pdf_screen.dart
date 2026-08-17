import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:printing/printing.dart';

import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_snack.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key, required this.pdfPath});

  final String pdfPath;

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  final Map<int, Future<pdfx.PdfPageImage?>> _thumbs = {};
  List<bool> _selected = [];
  pdfx.PdfDocument? _document;
  int _pageCount = 0;
  bool _loading = true;
  bool _busy = false;
  Future<void> _thumbQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await pdfx.PdfDocument.openFile(widget.pdfPath);
    _document = doc;
    _pageCount = doc.pagesCount;
    _selected
      ..clear()
      ..addAll(List<bool>.filled(_pageCount, false));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _document?.close();
    super.dispose();
  }

  Future<pdfx.PdfPageImage?> _getThumb(int pageNumber) {
    return _thumbs.putIfAbsent(
      pageNumber,
      () => _enqueueThumbRender(() => _renderThumb(_document!, pageNumber)),
    );
  }

  Future<pdfx.PdfPageImage?> _enqueueThumbRender(
    Future<pdfx.PdfPageImage?> Function() task,
  ) {
    final completer = Completer<pdfx.PdfPageImage?>();
    _thumbQueue = _thumbQueue.then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<pdfx.PdfPageImage?> _renderThumb(
    pdfx.PdfDocument doc,
    int pageNumber,
  ) async {
    final page = await doc.getPage(pageNumber, autoCloseAndroid: false);
    final width = 240.0;
    final height = (page.height / page.width) * width;
    final image = await page.render(
      width: width,
      height: height,
      format: pdfx.PdfPageImageFormat.png,
      quality: 80,
      backgroundColor: '#FFFFFF',
    );
    await page.close();
    return image;
  }

  Future<List<int>> _selectedPages() async {
    final pages = <int>[];
    for (int i = 0; i < _selected.length; i++) {
      if (_selected[i]) pages.add(i + 1);
    }
    return pages;
  }

  Future<Uint8List> _buildPdfBytes(List<int> pages) async {
    final doc = pw.Document();
    for (final pageNumber in pages) {
      final page = await _document!.getPage(
        pageNumber,
        autoCloseAndroid: false,
      );
      final width = 1200.0;
      final height = (page.height / page.width) * width;
      final image = await page.render(
        width: width,
        height: height,
        format: pdfx.PdfPageImageFormat.png,
        quality: 90,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      if (image == null) continue;
      final mem = pw.MemoryImage(image.bytes);
      final pageFormat = PdfPageFormat.a4;
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (_) => pw.Center(child: pw.Image(mem, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return doc.save();
  }

  Future<void> _savePdf() async {
    final pages = await _selectedPages();
    if (pages.isEmpty) {
      _show('Select at least one page.');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfBytes(pages);
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
        '${dir.path}/split_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Split PDF',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: pages.length,
        ),
      );
      if (!mounted) return;
      _show('Saved to Files');
    } catch (error) {
      debugPrint('Split PDF save failed: $error');
      if (mounted) _show('Could not save PDF: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPdf() async {
    final pages = await _selectedPages();
    if (pages.isEmpty) {
      _show('Select at least one page.');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfBytes(pages);
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
        '${dir.path}/split_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Split PDF',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: pages.length,
        ),
      );
      unawaited(
        Printing.layoutPdf(
          name: 'split_pdf.pdf',
          onLayout: (_) async => bytes,
        ).timeout(const Duration(seconds: 20)).catchError((error) {
          debugPrint('Split PDF print dialog failed: $error');
          return false;
        }),
      );
      if (!mounted) return;
    } catch (error) {
      debugPrint('Split PDF print failed: $error');
      if (mounted) _show('Could not print PDF: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleAll(bool value) {
    setState(() {
      _selected = List<bool>.filled(_pageCount, value);
    });
  }

  void _show(String message) {
    AppSnack.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF2B3A55),
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Text(
                          'Split PDF',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B3A55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _selected.where((v) => v).isEmpty
                              ? null
                              : _savePdf,
                          child: const Text('Save'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _selected.contains(false)
                              ? () => _toggleAll(true)
                              : null,
                          child: const Text('All'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _selected.contains(true)
                              ? () => _toggleAll(false)
                              : null,
                          child: const Text('Clear'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text(
                  'Pages: $_pageCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  'Selected: ${_selected.where((v) => v).length}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _pageCount,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    itemBuilder: (context, index) {
                      final pageNumber = index + 1;
                      final selected = _selected[index];
                      return InkWell(
                        onTap: () =>
                            setState(() => _selected[index] = !selected),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF2F8CFF)
                                  : const Color(0xFFE5E7EE),
                              width: selected ? 2 : 1.2,
                            ),
                            color: selected
                                ? const Color(0xFFF0F8FF)
                                : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: FutureBuilder<pdfx.PdfPageImage?>(
                                    future: _getThumb(pageNumber),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState !=
                                          ConnectionState.done) {
                                        return Center(
                                          child: Icon(
                                            Icons.picture_as_pdf,
                                            color: selected
                                                ? const Color(0xFF2F8CFF)
                                                : Colors.black54,
                                            size: 28,
                                          ),
                                        );
                                      }
                                      final img = snapshot.data;
                                      if (img == null || img.bytes.isEmpty) {
                                        return Center(
                                          child: Icon(
                                            Icons.picture_as_pdf,
                                            color: selected
                                                ? const Color(0xFF2F8CFF)
                                                : Colors.black54,
                                            size: 28,
                                          ),
                                        );
                                      }
                                      return Image.memory(
                                        img.bytes,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        filterQuality: FilterQuality.high,
                                        gaplessPlayback: true,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Page $pageNumber',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: selected
                                    ? const Color(0xFF2F8CFF)
                                    : Colors.black26,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _printPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F8CFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _busy ? 'Working...' : 'Print Selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
