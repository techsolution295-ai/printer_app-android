import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_snack.dart';

class PhotoPreScreen extends StatefulWidget {
  const PhotoPreScreen({super.key, required this.images});

  final List<XFile> images;

  @override
  State<PhotoPreScreen> createState() => _PhotoPreScreenState();
}

class _PhotoPreScreenState extends State<PhotoPreScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  Future<Uint8List> _buildPdfFromImages(List<XFile> images) async {
    final doc = pw.Document();
    for (final img in images) {
      final file = File(img.path);
      if (!file.existsSync()) continue;
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
    }
    return doc.save();
  }

  Future<void> _saveImages() async {
    if (_busy) return;
    final images = widget.images;
    if (images.isEmpty) {
      _show('No images found.');
      return;
    }
    setState(() => _busy = true);
    try {
      final dir = await _getSaveDir();
      await dir.create(recursive: true);
      final folder = Directory(
        '${dir.path}/photos_${DateTime.now().millisecondsSinceEpoch}',
      );
      await folder.create(recursive: true);
      for (int i = 0; i < images.length; i++) {
        final src = File(images[i].path);
        if (!src.existsSync()) continue;
        final ext = src.path.split('.').last;
        final target = File('${folder.path}/photo_${i + 1}.$ext');
        await src.copy(target.path);
      }
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Photo Print',
          type: 'images',
          filePath: folder.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: images.length,
        ),
      );
      if (!mounted) return;
      _show('Saved to Files');
    } catch (error) {
      debugPrint('Photo save failed: $error');
      if (mounted) _show('Could not save images: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printImages() async {
    if (_busy) return;
    final images = widget.images;
    if (images.isEmpty) {
      _show('No images found.');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfFromImages(images);
      if (bytes.isEmpty) {
        throw StateError('Generated PDF is empty.');
      }
      final dir = await _getSaveDir();
      await dir.create(recursive: true);
      final file = File(
        '${dir.path}/photos_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Photo Print',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: images.length,
        ),
      );
      unawaited(
        Printing.layoutPdf(
          name: 'photos.pdf',
          onLayout: (_) async => bytes,
        ).timeout(const Duration(seconds: 20)).catchError((error) {
          debugPrint('Photo print dialog failed: $error');
          return false;
        }),
      );
      if (!mounted) return;
    } catch (error) {
      debugPrint('Photo print failed: $error');
      if (mounted) _show('Could not print images: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    AppSnack.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final current = images[_currentIndex];
    final file = File(current.path);
    final fileSize = _formatBytes(file.existsSync() ? file.lengthSync() : 0);

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
          'Photo Preview',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: _PreviewHeader(
              fileSize: fileSize,
              count: images.length,
              index: _currentIndex + 1,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: _PhotoPager(
                controller: _pageController,
                images: images,
                onPageChanged: (index) => setState(() => _currentIndex = index),
              ),
            ),
          ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _ThumbnailRow(
                images: images,
                currentIndex: _currentIndex,
                onTap: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ),
          _BottomActions(
            onPrint: _busy ? null : _printImages,
            onSave: _busy ? null : _saveImages,
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.fileSize,
    required this.count,
    required this.index,
  });

  final String fileSize;
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF27AE60), Color(0xFF6FCF97)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF27AE60).withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.photo_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photo Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2B3A55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'JPG/PNG • $fileSize • $index/$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B8BA6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoPager extends StatelessWidget {
  const _PhotoPager({
    required this.controller,
    required this.images,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<XFile> images;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: PageView.builder(
          controller: controller,
          onPageChanged: onPageChanged,
          itemCount: images.length,
          itemBuilder: (context, index) {
            final file = File(images[index].path);
            return file.existsSync()
                ? Image.file(
                    file,
                    fit: BoxFit.contain,
                  )
                : const Center(
                    child: Text(
                      'Image not found',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  );
          },
        ),
      ),
    );
  }
}

class _ThumbnailRow extends StatelessWidget {
  const _ThumbnailRow({
    required this.images,
    required this.currentIndex,
    required this.onTap,
  });

  final List<XFile> images;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final file = File(images[index].path);
          final isActive = index == currentIndex;
          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF27AE60)
                      : const Color(0xFFE2E8F0),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover)
                    : const ColoredBox(color: Color(0xFFE2E8F0)),
              ),
            ),
          );
        },
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
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded, size: 20),
                label: const Text(
                  'Print',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
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

String _formatBytes(int bytes) {
  const suffixes = ['B', 'KB', 'MB', 'GB'];
  double size = bytes.toDouble();
  var suffixIndex = 0;
  while (size >= 1024 && suffixIndex < suffixes.length - 1) {
    size /= 1024;
    suffixIndex++;
  }
  return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[suffixIndex]}';
}
