import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/labels.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ads/ad_service.dart';
import '../config/pro_theme.dart';
import '../database/data-base.dart';
import '../models/print_history_model.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snack.dart';

class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key});

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  final GlobalKey _repaintKey = GlobalKey();
  final TextEditingController _urlController = TextEditingController();
  Timer? _loadTimeout;

  bool _isLoading = true;
  bool _isPrinting = false;
  String? _pageError;

  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();

    _startLoadWatchdog();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _pageError = null;
              });
            }
            _startLoadWatchdog();
          },
          onPageFinished: (_) {
            _clearLoadWatchdog();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _pageError = null;
              });
            }
          },
          onProgress: (progress) {
            if (!mounted) return;
            if (progress >= 100) {
              _clearLoadWatchdog();
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            _clearLoadWatchdog();
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _pageError = error.description.isNotEmpty
                  ? error.description
                  : t(context, 'web_failed');
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.google.com'));
    _urlController.text = 'https://www.google.com';
  }

  @override
  void dispose() {
    _clearLoadWatchdog();
    _urlController.dispose();
    super.dispose();
  }

  void _startLoadWatchdog() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_isLoading) return;
      setState(() {
        _isLoading = false;
        _pageError = t(context, 'web_timeout');
      });
    });
  }

  void _clearLoadWatchdog() {
    _loadTimeout?.cancel();
    _loadTimeout = null;
  }

  void _loadUrl() {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return;
    final withScheme = raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) return;
    setState(() {
      _isLoading = true;
      _pageError = null;
    });
    _controller.loadRequest(uri);
  }

  Future<void> _printFullPage() async {
    if (_isPrinting || _repaintKey.currentContext == null) return;

    setState(() {
      _isPrinting = true;
      _currentPage = 0;
      _totalPages = 0;
    });

    try {
      final pdf = pw.Document();
      final result = await _controller.runJavaScriptReturningResult(
        'document.body.scrollHeight.toString();',
      );
      final totalHeight =
          double.tryParse(result.toString().replaceAll('"', '')) ?? 0;
      if (!mounted) return;
      if (totalHeight <= 0) {
        AppSnack.show(context, t(context, 'nothing_to_print'));
        return;
      }

      final viewHeight = MediaQuery.sizeOf(context).height;
      _totalPages = min((totalHeight / viewHeight).ceil(), 8);

      final boundaryObject = _repaintKey.currentContext?.findRenderObject();
      if (boundaryObject is! RenderRepaintBoundary) {
        AppSnack.show(context, t(context, 'could_not_print'));
        return;
      }
      final boundary = boundaryObject;

      for (int i = 0; i < _totalPages; i++) {
        if (!mounted) break;
        setState(() => _currentPage = i + 1);

        await _controller.runJavaScript(
          'window.scrollTo(0, ${i * viewHeight});',
        );
        await Future.delayed(const Duration(milliseconds: 400));

        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData == null) continue;

        final Uint8List imgBytes = byteData.buffer.asUint8List();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) =>
                pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.contain),
          ),
        );
      }

      final Directory dir;
      if (Platform.isAndroid) {
        final external = await getExternalStorageDirectory();
        dir = external ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final filePath =
          '${dir.path}/Web_Print_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Web Print',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: _totalPages,
        ),
      );

      if (!mounted) return;
      await Printing.layoutPdf(
        name: 'web_page.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      debugPrint('Print error: $e');
      if (mounted) {
        AppSnack.show(context, t(context, 'could_not_print'));
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkHeaderOverlay,
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4D6FA6), Color(0xFF344C73)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      t(context, 'feat_web'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _controller.reload(),
                    icon: const Icon(Icons.refresh_rounded),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public_rounded,
                          color: AppTheme.actionColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _loadUrl(),
                          decoration: InputDecoration(
                            hintText: t(context, 'paste_url'),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadUrl,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        color: AppTheme.actionColor,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: IgnorePointer(
                        ignoring: _isPrinting,
                        child: Opacity(
                          opacity: 1,
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: WebViewWidget(controller: _controller),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            ColoredBox(
              color: const Color(0x66F4F7FB),
              child: AppLoader(message: t(context, 'loading_page')),
            ),
          if (_pageError != null && !_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 42,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _pageError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2B3A55),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadUrl,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(t(context, 'retry')),
                    ),
                  ],
                ),
              ),
            ),
          if (_isPrinting)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      t(context, 'preparing_page', namedArgs: {
                        'current': '$_currentPage',
                        'total': '$_totalPages',
                      }),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.print, color: Colors.white),
              label: Text(
                t(context, 'print_full_page'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2F80ED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isPrinting ? null : afterInterstitial(_printFullPage),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
