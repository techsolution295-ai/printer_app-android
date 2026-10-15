import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

import '../l10n/labels.dart';
import '../ads/ad_service.dart';
import '../ads/banner_ad_widget.dart';
import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snack.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  late Future<List<PrintHistory>> _historyFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _historyFuture = HistoryDB.instance.getAllHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = HistoryDB.instance.getAllHistory();
    });
  }

  Future<void> _printItem(PrintHistory item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (item.type == 'images') {
        final dir = Directory(item.filePath);
        if (!await dir.exists()) {
          AppSnack.show(context, t(context, 'folder_gone'));
          return;
        }

        final imageFiles =
            await dir
                  .list()
                  .where((e) => e is File)
                  .cast<File>()
                  .where(
                    (f) => RegExp(
                      r'\.(png|jpg|jpeg)$',
                      caseSensitive: false,
                    ).hasMatch(f.path),
                  )
                  .toList()
              ..sort((a, b) => a.path.compareTo(b.path));

        if (imageFiles.isEmpty) {
          AppSnack.show(context, t(context, 'no_printable_images'));
          return;
        }

        final pdf = pw.Document();
        for (final file in imageFiles) {
          final bytes = await file.readAsBytes();
          final image = pw.MemoryImage(bytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) =>
                  pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
            ),
          );
        }

        final pdfBytes = await pdf.save();
        if (!mounted) return;
        await openPrintLayout(name: '${item.title}.pdf', bytes: pdfBytes);
        return;
      }

      final file = File(item.filePath);
      if (!await file.exists()) {
        if (!mounted) return;
        AppSnack.show(context, t(context, 'file_not_found'));
        return;
      }

      final Uint8List bytes;
      final lower = item.filePath.toLowerCase();
      if (lower.endsWith('.pdf')) {
        bytes = await file.readAsBytes();
      } else if (lower.endsWith('.txt')) {
        final text = await file.readAsString();
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (_) => [
              pw.Paragraph(text: text, style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        );
        bytes = await doc.save();
      } else if (RegExp(
        r'\.(png|jpg|jpeg|webp)$',
        caseSensitive: false,
      ).hasMatch(lower)) {
        final imageBytes = await file.readAsBytes();
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(
              child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
            ),
          ),
        );
        bytes = await doc.save();
      } else {
        if (!mounted) return;
        AppSnack.show(context, t(context, 'cannot_print_type'));
        return;
      }

      if (!mounted) return;
      await openPrintLayout(name: item.title, bytes: bytes);
    } catch (e, stack) {
      debugPrint('Print error: $e\n$stack');
      if (mounted) AppSnack.show(context, t(context, 'could_not_print_retry'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteItem(PrintHistory item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (item.type == 'images') {
        final dir = Directory(item.filePath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } else {
        final file = File(item.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (item.id != null) {
        await HistoryDB.instance.deleteHistory(item.id!);
      }

      await _refresh();
      if (!mounted) return;
      AppSnack.show(context, t(context, 'deleted'));
    } catch (_) {
      if (mounted) AppSnack.show(context, t(context, 'delete_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final items = await HistoryDB.instance.getAllHistory();
      for (final item in items) {
        if (item.type == 'images') {
          final dir = Directory(item.filePath);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } else {
          final file = File(item.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
      await HistoryDB.instance.clearHistory();
      await _refresh();
      if (!mounted) return;
      AppSnack.show(context, t(context, 'all_cleared'));
    } catch (_) {
      if (mounted) AppSnack.show(context, t(context, 'clear_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog.adaptive(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text('delete'.tr()),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openPreview(PrintHistory item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FilePreviewScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBusyOverlay(
      busy: _busy,
      message: 'please_wait'.tr(),
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'print_history'.tr(),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t(context, 'refresh'),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: t(context, 'clear_all'),
            onPressed: () async {
              final confirmed = await _confirm(
                context,
                'clear_everything'.tr(),
                'clear_everything_body'.tr(),
              );
              if (confirmed) {
                await _deleteAll();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const BannerAdWidget(
            margin: EdgeInsets.fromLTRB(12, 6, 12, 6),
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        color: colorScheme.primary,
        child: FutureBuilder<List<PrintHistory>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppLoader(message: 'loading_files'.tr());
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _HistoryColumnItem(
                  item: item,
                  onTap: () => _openPreview(item),
                  onPrint: afterInterstitial(() => _printItem(item)),
                  onDelete: () async {
                    final confirmed = await _confirm(
                      context,
                      'delete_print'.tr(),
                      'cannot_undo'.tr(),
                    );
                    if (confirmed) {
                      await _deleteItem(item);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            'no_history'.tr(),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'no_history_sub'.tr(),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _HistoryColumnItem extends StatelessWidget {
  const _HistoryColumnItem({
    required this.item,
    required this.onTap,
    required this.onPrint,
    required this.onDelete,
  });

  final PrintHistory item;
  final VoidCallback onTap;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isImages = item.type == 'images';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      isImages
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                      color: const Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedHistoryTitle(context, item.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.createdAt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t(context, 'type_line', namedArgs: {
                  'type': isImages
                      ? t(context, 'type_images')
                      : t(context, 'type_pdf'),
                }),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              if (item.pages != null) ...[
                const SizedBox(height: 2),
                Text(
                  t(context, 'pages_count', namedArgs: {
                    'count': '${item.pages}',
                  }),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: Text('preview'.tr()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onPrint,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: Text('print'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: t(context, 'delete'),
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red.shade600,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilePreviewScreen extends StatelessWidget {
  final PrintHistory item;

  const FilePreviewScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          localizedHistoryTitle(context, item.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: item.type == 'images'
          ? _MultiImagePreview(path: item.filePath)
          : _isPdfFile(item.filePath)
          ? _PdfViewer(path: item.filePath)
          : Center(
              child: Text(
                t(context, 'no_preview_type'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
    );
  }

  bool _isPdfFile(String path) => path.toLowerCase().endsWith('.pdf');
}

class _MultiImagePreview extends StatelessWidget {
  final String path;

  const _MultiImagePreview({required this.path});

  @override
  Widget build(BuildContext context) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      return Center(
        child: Text(
          t(context, 'folder_not_found'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    final images =
        dir
            .listSync()
            .whereType<File>()
            .where(
              (f) => RegExp(
                r'\.(png|jpg|jpeg)$',
                caseSensitive: false,
              ).hasMatch(f.path),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    if (images.isEmpty) {
      return Center(
        child: Text(
          t(context, 'no_images'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: images.length,
      itemBuilder: (context, i) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            images[i],
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) {
                return child;
              }
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}

class _PdfViewer extends StatefulWidget {
  final String path;

  const _PdfViewer({required this.path});

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  late pdfx.PdfControllerPinch _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = pdfx.PdfControllerPinch(
      document: pdfx.PdfDocument.openFile(widget.path),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: pdfx.PdfViewPinch(
            controller: _pdfController,
            scrollDirection: Axis.vertical,
            builders: appPdfPinchBuilders(),
          ),
        ),
      ),
    );
  }
}
