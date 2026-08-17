import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';

import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_snack.dart';

class DocPreScreen extends StatelessWidget {
  const DocPreScreen({super.key, required this.file});

  final PlatformFile file;

  Future<Directory> _getSaveDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  Future<File?> _copyToDownloads(BuildContext context) async {
    final filePath = file.path ?? '';
    if (filePath.isEmpty || !File(filePath).existsSync()) {
      AppSnack.show(context, 'File not found.');
      return null;
    }
    final dir = await _getSaveDir();
    final target = File('${dir.path}/${file.name}');
    await File(filePath).copy(target.path);
    return target;
  }

  Future<void> _saveFile(BuildContext context) async {
    final saved = await _copyToDownloads(context);
    if (saved == null) return;
    await HistoryDB.instance.insertHistory(
      PrintHistory(
        title: file.name,
        type: 'file',
        filePath: saved.path,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    if (!context.mounted) return;
    AppSnack.show(context, 'Saved to Files');
  }

  Future<void> _printFile(BuildContext context) async {
    final filePath = file.path ?? '';
    if (filePath.isEmpty || !File(filePath).existsSync()) {
      AppSnack.show(context, 'File not found.');
      return;
    }
    final extension = _extensionOf(file.name);
    if (extension != 'PDF') {
      AppSnack.show(context, 'Only PDF printing is supported.');
      return;
    }
    final bytes = await File(filePath).readAsBytes();
    final saved = await _copyToDownloads(context);
    if (saved != null) {
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: file.name,
          type: 'pdf',
          filePath: saved.path,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    unawaited(
      Printing.layoutPdf(
        name: '${file.name}.pdf',
        onLayout: (_) async => bytes,
      ).timeout(const Duration(seconds: 20)).catchError((error) {
        debugPrint('Document print dialog failed: $error');
        return false;
      }),
    );
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }


  @override
  Widget build(BuildContext context) {
    final filePath = file.path ?? '';
    final fileName = file.name;
    final fileSize = _formatBytes(file.size);
    final extension = _extensionOf(fileName);
    final isPdf = extension == 'PDF';
    final canRead = filePath.isNotEmpty && File(filePath).existsSync();

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
          'Document Preview',
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
              extension: extension,
              fileSize: fileSize,
              isPdf: isPdf,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: isPdf && canRead
                  ? _PdfPreview(filePath: filePath)
                  : _PreviewCard(
                      fileName: fileName,
                      fileSize: fileSize,
                      extension: extension,
                      hasPreview: canRead,
                      showName: !isPdf,
                    ),
            ),
          ),
          _BottomActions(
            onPrint: () => _printFile(context),
            onSave: () => _saveFile(context),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.extension,
    required this.fileSize,
    required this.isPdf,
  });

  final String extension;
  final String fileSize;
  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    final label = isPdf ? 'PDF Preview' : 'Document Preview';
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F80ED).withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.picture_as_pdf_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2B3A55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$extension - $fileSize',
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.fileName,
    required this.fileSize,
    required this.extension,
    required this.hasPreview,
    required this.showName,
  });

  final String fileName;
  final String fileSize;
  final String extension;
  final bool hasPreview;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 140,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E8F7)),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 52,
              color: Color(0xFF2F80ED),
            ),
          ),
          const SizedBox(height: 16),
          if (showName) ...[
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            '$extension - $fileSize',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7B8BA6),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasPreview
                ? 'Preview ready'
                : 'Preview not available for this file',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasPreview
                  ? const Color(0xFF27AE60)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.filePath});

  final String filePath;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        child: ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: PdfViewPinch(
            controller: _controller,
            scrollDirection: Axis.vertical,
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onPrint, required this.onSave});

  final VoidCallback onPrint;
  final VoidCallback onSave;

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

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot == -1 || dot == fileName.length - 1) {
    return 'FILE';
  }
  return fileName.substring(dot + 1).toUpperCase();
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
