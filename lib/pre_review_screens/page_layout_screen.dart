import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_snack.dart';
class PageLayoutScreen extends StatefulWidget {
  const PageLayoutScreen.pdf({super.key, required this.pdfPath})
      : images = const [];

  const PageLayoutScreen.images({super.key, required this.images})
      : pdfPath = null;

  final String? pdfPath;
  final List<PlatformFile> images;

  @override
  State<PageLayoutScreen> createState() => _PageLayoutScreenState();
}

class _PageLayoutScreenState extends State<PageLayoutScreen> {
  final List<int> _pageOrder = [];
  final List<PlatformFile> _imageOrder = [];
  final Map<int, Future<pdfx.PdfPageImage?>> _pageThumbs = {};
  Future<void> _thumbQueue = Future.value();
  pdfx.PdfDocument? _document;
  int _pageCount = 0;
  bool _isLoading = false;
  bool _busy = false;

  bool get _isPdf => widget.pdfPath != null;

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _loadPdf();
    } else {
      _imageOrder
        ..clear()
        ..addAll(widget.images);
    }
  }

  Future<void> _loadPdf() async {
    setState(() => _isLoading = true);
    final doc = await pdfx.PdfDocument.openFile(widget.pdfPath!);
    _document = doc;
    _pageCount = doc.pagesCount;
    _pageOrder
      ..clear()
      ..addAll(List<int>.generate(_pageCount, (index) => index + 1));
    _pageThumbs.clear();
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _document?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readyToExport = !_isPdf || (_document != null && _pageOrder.isNotEmpty);
    return Scaffold(
      backgroundColor: Colors.white,
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
          'Page Layout',
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
                  _isPdf ? 'Drag to reorder pages' : 'Drag to reorder images',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: _isPdf ? _buildPdfList() : _buildImageList(),
            ),
          ),
          _BottomActions(
            busy: _busy,
            enabled: readyToExport,
            onSave: _saveOrder,
            onPrint: _printOrder,
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();

    if (_isPdf) {
      for (final pageNumber in _pageOrder) {
        final bytes = await _renderPdfPageBytes(pageNumber);
        if (bytes == null || bytes.isEmpty) {
          continue;
        }
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
    } else {
      for (final file in _imageOrder) {
        final path = file.path;
        if (path == null || path.isEmpty || !File(path).existsSync()) {
          continue;
        }
        final bytes = await File(path).readAsBytes();
        if (bytes.isEmpty) {
          continue;
        }
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
    }

    return doc.save();
  }

  Future<Uint8List?> _renderPdfPageBytes(int pageNumber) async {
    if (_document == null) {
      return null;
    }
    final page = await _document!.getPage(pageNumber, autoCloseAndroid: false);
    final width = 900.0;
    final height = (page.height / page.width) * width;
    final image = await page.render(
      width: width,
      height: height,
      format: pdfx.PdfPageImageFormat.png,
      quality: 70,
      backgroundColor: '#FFFFFF',
    );
    await page.close();
    return image?.bytes;
  }

  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _saveOrder() async {
    if ((_isPdf && (_document == null || _pageOrder.isEmpty)) ||
        (!_isPdf && _imageOrder.isEmpty)) {
      AppSnack.show(context, 'No pages selected.');
      return;
    }

    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfBytes();
      if (bytes.isEmpty) {
        throw StateError('Generated PDF is empty.');
      }
      final dir = await _getSaveDirectory();
      await dir.create(recursive: true);
      final file = File(
        '${dir.path}/page_layout_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Page Layout',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: _isPdf ? _pageOrder.length : _imageOrder.length,
        ),
      );
      if (!mounted) {
        return;
      }
      AppSnack.show(context, 'Saved to Files');
    } catch (error) {
      debugPrint('Save order failed: $error');
      if (mounted) {
        AppSnack.show(context, 'Could not save PDF: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _printOrder() async {
    if ((_isPdf && (_document == null || _pageOrder.isEmpty)) ||
        (!_isPdf && _imageOrder.isEmpty)) {
      AppSnack.show(context, 'No pages selected.');
      return;
    }

    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfBytes();
      if (bytes.isEmpty) {
        throw StateError('Generated PDF is empty.');
      }
      unawaited(
        Printing.layoutPdf(
          name: 'page_layout.pdf',
          onLayout: (_) async => bytes,
        ).timeout(const Duration(seconds: 20)).catchError((error) {
          debugPrint('Page Layout print dialog failed: $error');
          return false;
        }),
      );
    } catch (error) {
      debugPrint('Print order failed: $error');
      if (mounted) {
        AppSnack.show(context, 'Could not start print: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _buildPdfList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pageCount == 0 || _document == null) {
      return const Center(
        child: Text(
          'No pages found',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: _pageOrder.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = _pageOrder.removeAt(oldIndex);
          _pageOrder.insert(newIndex, item);
        });
      },
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (context, index) {
        final pageNumber = _pageOrder[index];
        return _PageTile(
          key: ValueKey('page_$pageNumber'),
          title: 'Page $pageNumber',
          subtitle: 'PDF preview',
          leading: _PdfThumb(
            future: _getPageThumb(pageNumber),
          ),
        );
      },
    );
  }

  Future<pdfx.PdfPageImage?> _getPageThumb(int pageNumber) {
    return _pageThumbs.putIfAbsent(
      pageNumber,
      () => _enqueueThumbRender(() => _renderPdfThumb(_document!, pageNumber)),
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

  Future<pdfx.PdfPageImage?> _renderPdfThumb(
    pdfx.PdfDocument document,
    int pageNumber,
  ) async {
    final page = await document.getPage(pageNumber, autoCloseAndroid: false);
    final width = 220.0;
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

  Widget _buildImageList() {
    if (_imageOrder.isEmpty) {
      return const Center(
        child: Text(
          'No images selected',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: _imageOrder.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = _imageOrder.removeAt(oldIndex);
          _imageOrder.insert(newIndex, item);
        });
      },
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (context, index) {
        final file = _imageOrder[index];
        return _PageTile(
          key: ValueKey('img_${file.path ?? index}'),
          title: 'Image ${index + 1}',
          subtitle: file.name,
          leading: _ImageThumb(path: file.path),
        );
      },
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
  });

  final String title;
  final String subtitle;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(height: 52, width: 52, child: leading),
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
          color: const Color(0xFFF1F5FA),
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

class _PdfThumb extends StatelessWidget {
  const _PdfThumb({required this.future});

  final Future<pdfx.PdfPageImage?> future;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<pdfx.PdfPageImage?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ColoredBox(
              color: Color(0xFFF1F5FA),
              child: Center(
                child: Icon(
                  Icons.picture_as_pdf,
                  color: Colors.black54,
                  size: 28,
                ),
              ),
            );
          }
          final img = snapshot.data;
          if (img == null || img.bytes.isEmpty) {
            return const ColoredBox(
              color: Color(0xFFF1F5FA),
              child: Center(
                child: Icon(
                  Icons.picture_as_pdf,
                  color: Colors.black54,
                  size: 28,
                ),
              ),
            );
          }
          return Image.memory(img.bytes, fit: BoxFit.cover);
        },
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.busy,
    required this.enabled,
    required this.onSave,
    required this.onPrint,
  });

  final bool busy;
  final bool enabled;
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
                onPressed: busy || !enabled ? null : onSave,
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'Save Order',
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
                onPressed: busy || !enabled ? null : onPrint,
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
