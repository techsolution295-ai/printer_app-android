import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import '../l10n/labels.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../ads/ad_service.dart';
import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snack.dart';
import '../widgets/pro_crown_icon.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key, required this.pdfPath});

  final String pdfPath;

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
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
    try {
      final doc = await pdfx.PdfDocument.openFile(widget.pdfPath);
      _document = doc;
      _pageCount = doc.pagesCount;
      _selected
        ..clear()
        ..addAll(List<bool>.filled(_pageCount, true));
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      debugPrint('PDF to image load failed: $error');
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnack.show(context, t(context, 'could_not_open_pdf'));
    }
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
    final width = 260.0;
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

  Future<List<Uint8List>> _renderSelectedImages(List<int> pages) async {
    final results = <Uint8List>[];
    for (final pageNumber in pages) {
      final page = await _document!.getPage(
        pageNumber,
        autoCloseAndroid: false,
      );
      final width = 1400.0;
      final height = (page.height / page.width) * width;
      final image = await page.render(
        width: width,
        height: height,
        format: pdfx.PdfPageImageFormat.png,
        quality: 90,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      if (image != null && image.bytes.isNotEmpty) {
        results.add(image.bytes);
      }
    }
    return results;
  }

  Future<Uint8List> _buildPdfFromImages(List<Uint8List> images) async {
    final doc = pw.Document();
    for (final bytes in images) {
      final mem = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(child: pw.Image(mem, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return doc.save();
  }

  Future<void> _saveImages() async {
    final pages = await _selectedPages();
    if (pages.isEmpty) {
      _show(t(context, 'select_one_page'));
      return;
    }
    setState(() => _busy = true);
    try {
      final images = await _renderSelectedImages(pages);
      final Directory dir;
      if (Platform.isAndroid) {
        final external = await getExternalStorageDirectory();
        dir = external ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      await dir.create(recursive: true);
      final folder = Directory(
        '${dir.path}/pdf_images_${DateTime.now().millisecondsSinceEpoch}',
      );
      await folder.create(recursive: true);
      for (int i = 0; i < images.length; i++) {
        final file = File('${folder.path}/page_${i + 1}.png');
        await file.writeAsBytes(images[i], flush: true);
      }
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'PDF to Image',
          type: 'images',
          filePath: folder.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: images.length,
        ),
      );
      if (!mounted) return;
      _show(t(context, 'saved_to_files'));
    } catch (error) {
      debugPrint('PDF to Image save failed: $error');
      if (mounted) _show(t(context, 'could_not_save_images', namedArgs: {'error': '$error'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printImages() async {
    final pages = await _selectedPages();
    if (pages.isEmpty) {
      _show(t(context, 'select_one_page'));
      return;
    }
    setState(() => _busy = true);
    try {
      final images = await _renderSelectedImages(pages);
      final bytes = await _buildPdfFromImages(images);
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
        '${dir.path}/pdf_to_image_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'PDF to Image (Print)',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: images.length,
        ),
      );
      if (!mounted) return;
      await openPrintLayout(name: 'pdf_to_image.pdf', bytes: bytes);
      if (!mounted) return;
    } catch (error) {
      debugPrint('PDF to Image print failed: $error');
      if (mounted) _show(t(context, 'could_not_print_pdf', namedArgs: {'error': '$error'}));
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
    return AppBusyOverlay(
      busy: _busy,
      message: t(context, 'please_wait'),
      child: Scaffold(
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
                        Text(
                          t(context, 'feat_pdf_to_image'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B3A55),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: const ProAppBarButton(),
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
                              : afterInterstitial(_saveImages),
                          child: Text(t(context, 'save')),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _selected.contains(false)
                              ? () => _toggleAll(true)
                              : null,
                          child: Text(t(context, 'all')),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _selected.contains(true)
                              ? () => _toggleAll(false)
                              : null,
                          child: Text(t(context, 'clear')),
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
                  t(context, 'pages_count', namedArgs: {'count': '$_pageCount'}),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  t(context, 'selected_count', namedArgs: {
                    'count': '${_selected.where((v) => v).length}',
                  }),
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? AppLoader(message: t(context, 'loading_pages'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: _pageCount,
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
                                t(context, 'page_n', namedArgs: {'n': '$pageNumber'}),
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
                  onPressed: _busy ? null : afterInterstitial(_printImages),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F8CFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _busy ? t(context, 'working') : t(context, 'print_selected'),
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
    ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.count, required this.selected});

  final int count;
  final int selected;

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
              Icons.image_rounded,
              color: AppTheme.actionColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(context, 'pages_selected', namedArgs: {
                'count': '$count',
                'selected': '$selected',
              }),
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

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.pageNumber,
    required this.selected,
    required this.onTap,
    required this.thumb,
  });

  final int pageNumber;
  final bool selected;
  final VoidCallback onTap;
  final Widget thumb;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.actionColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: SizedBox.expand(child: thumb),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text(
                    t(context, 'page_n', namedArgs: {'n': '$pageNumber'}),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B3A55),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? AppTheme.actionColor
                        : const Color(0xFFCBD5E1),
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfThumb extends StatelessWidget {
  const _PdfThumb({required this.future});

  final Future<pdfx.PdfPageImage?> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<pdfx.PdfPageImage?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFFEAF2FF),
            child: Center(
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final img = snapshot.data;
        if (img == null || img.bytes.isEmpty) {
          return const ColoredBox(
            color: Color(0xFFEAF2FF),
            child: Center(
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: AppTheme.actionColor,
                size: 18,
              ),
            ),
          );
        }
        return Image.memory(img.bytes, fit: BoxFit.cover);
      },
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
