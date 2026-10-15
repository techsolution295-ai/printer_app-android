import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import 'package:path_provider/path_provider.dart';

import '../ads/ad_service.dart';
import '../ads/banner_ad_widget.dart';
import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../printables/printable_item.dart';
import '../printables/printables_service.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snack.dart';
import '../widgets/pro_crown_icon.dart';

class PrintableDetailScreen extends StatefulWidget {
  const PrintableDetailScreen({super.key, required this.item});

  final PrintableItem item;

  @override
  State<PrintableDetailScreen> createState() => _PrintableDetailScreenState();
}

class _PrintableDetailScreenState extends State<PrintableDetailScreen> {
  bool _busy = false;
  Uint8List? _pdfBytes;

  static const _headers = {
    'User-Agent': 'SmartPrinter/1.0',
    'Accept': 'image/*,*/*;q=0.8',
  };

  Future<Uint8List> _readyPdf() async {
    final cached = _pdfBytes;
    if (cached != null) return cached;
    final bytes = await PrintablesService.instance.buildPrintablePdf(widget.item);
    _pdfBytes = bytes;
    return bytes;
  }

  Future<void> _saveFile(Uint8List bytes) async {
    final Directory dir;
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      dir = external ?? await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}/${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await HistoryDB.instance.insertHistory(
      PrintHistory(
        title: widget.item.title,
        type: 'pdf',
        filePath: file.path,
        createdAt: DateTime.now().toIso8601String(),
        pages: 1,
      ),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _readyPdf();
      await _saveFile(bytes);
      if (!mounted) return;
      AppSnack.show(context, 'saved_to_files'.tr());
    } catch (error) {
      debugPrint('Printable save failed: $error');
      if (mounted) AppSnack.show(context, 'could_not_save'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _readyPdf();
      await _saveFile(bytes);
      if (!mounted) return;
      await openPrintLayout(name: '${widget.item.title}.pdf', bytes: bytes);
    } catch (error) {
      debugPrint('Printable print failed: $error');
      if (mounted) AppSnack.show(context, 'could_not_print'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AppBusyOverlay(
      busy: _busy,
      message: 'preparing_print'.tr(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.actionColor,
              ),
            ),
          ),
          leadingWidth: 84,
          centerTitle: true,
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F3A45),
            ),
          ),
          actions: const [
            ProAppBarButton(),
          ],
        ),
        body: Column(
          children: [
            const BannerAdWidget(
              margin: EdgeInsets.fromLTRB(12, 4, 12, 0),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6E8EC)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: item.previewUrl,
                    fit: BoxFit.contain,
                    httpHeaders: _headers,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppTheme.actionColor,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            if (item.source != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${'source'.tr()}: ${item.source}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A94A0),
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : afterInterstitial(_save),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2B3A55),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'save'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : afterInterstitial(_print),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.actionColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'print'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
