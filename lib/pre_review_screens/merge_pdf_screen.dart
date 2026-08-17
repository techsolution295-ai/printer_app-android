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

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key, required this.pdfPaths});

  final List<String> pdfPaths;

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<_PdfItem> _items = [];
  final List<_PdfPageItem> _pages = [];
  final Map<String, Future<pdfx.PdfPageImage?>> _pageThumbs = {};
  bool _loading = true;
  bool _busy = false;
  Future<void> _thumbQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = <_PdfItem>[];
    final pages = <_PdfPageItem>[];
    for (final path in widget.pdfPaths) {
      final doc = await pdfx.PdfDocument.openFile(path);
      final count = doc.pagesCount;
      await doc.close();
      items.add(_PdfItem(path: path, pages: count));
      for (int i = 1; i <= count; i++) {
        pages.add(_PdfPageItem(path: path, pageNumber: i));
      }
    }
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(items);
      _pages
        ..clear()
        ..addAll(pages);
      _loading = false;
    });
  }

  Future<pdfx.PdfPageImage?> _getPageThumb(String path, int pageNumber) {
    if (_busy) {
      return Future.value(null);
    }
    final key = '$path|$pageNumber';
    return _pageThumbs.putIfAbsent(
      key,
      () => _enqueueThumbRender(() => _renderPage(path, pageNumber)),
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

  Future<pdfx.PdfPageImage?> _renderPage(String path, int pageNumber) async {
    final doc = await pdfx.PdfDocument.openFile(path);
    final page = await doc.getPage(pageNumber, autoCloseAndroid: false);
    final width = 220.0;
    final height = (page.height / page.width) * width;
    final image = await page.render(
      width: width,
      height: height,
      format: pdfx.PdfPageImageFormat.png,
      quality: 90,
      backgroundColor: '#FFFFFF',
    );
    await page.close();
    await doc.close();
    return image;
  }

  Future<Uint8List> _buildMergedPdf() async {
    final doc = pw.Document();
    await _thumbQueue;
    for (final item in _items) {
      final source = await pdfx.PdfDocument.openFile(item.path);
      for (int i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i, autoCloseAndroid: false);
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
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(
              child: pw.Image(mem, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }
      await source.close();
    }
    return doc.save();
  }

  Future<void> _saveMerged() async {
    setState(() => _busy = true);
    try {
      final bytes = await _buildMergedPdf();
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
        '${dir.path}/merge_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Merge PDF',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      if (!mounted) return;
      _show('Saved to Files');
    } catch (error) {
      debugPrint('Merge PDF save failed: $error');
      if (mounted) _show('Could not save PDF: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printMerged() async {
    setState(() => _busy = true);
    try {
      final bytes = await _buildMergedPdf();
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
        '${dir.path}/merge_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Merge PDF',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      unawaited(
        Printing.layoutPdf(
          name: 'merge_pdf.pdf',
          onLayout: (_) async => bytes,
        ).timeout(const Duration(seconds: 20)).catchError((error) {
          debugPrint('Merge PDF print dialog failed: $error');
          return false;
        }),
      );
      if (!mounted) return;
    } catch (error) {
      debugPrint('Merge PDF print failed: $error');
      if (mounted) _show('Could not print PDF: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
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
          'Merge PDF',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text(
                  'Files: ${_items.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  'Pages: ${_pages.length}',
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
                    itemCount: _pages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      return _PdfPageTile(
                        pageIndex: index + 1,
                        thumb: _PdfPageThumb(
                          future: _getPageThumb(
                            item.path,
                            item.pageNumber,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _BottomActions(
            busy: _busy,
            onSave: _saveMerged,
            onPrint: _printMerged,
          ),
        ],
      ),
    );
  }
}

class _PdfItem {
  _PdfItem({required this.path, required this.pages});

  final String path;
  final int pages;

  String get name => path.split(Platform.pathSeparator).last;
}

class _PdfPageItem {
  _PdfPageItem({required this.path, required this.pageNumber});

  final String path;
  final int pageNumber;
}

class _PdfPageTile extends StatelessWidget {
  const _PdfPageTile({
    required this.pageIndex,
    required this.thumb,
  });

  final int pageIndex;
  final Widget thumb;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EE),
          width: 1.2,
        ),
        color: Colors.white,
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
              child: thumb,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Page $pageIndex',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PdfPageThumb extends StatelessWidget {
  const _PdfPageThumb({required this.future});

  final Future<pdfx.PdfPageImage?> future;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF1F5FA)),
      child: FutureBuilder<pdfx.PdfPageImage?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          final img = snapshot.data;
          if (img == null || img.bytes.isEmpty) {
            return const SizedBox.shrink();
          }
          return Image.memory(
            img.bytes,
            fit: BoxFit.cover,
            width: double.infinity,
          );
        },
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
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: busy ? null : onPrint,
                icon: const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  busy ? 'Working...' : 'Print',
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
