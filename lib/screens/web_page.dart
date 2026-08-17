import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../database/data-base.dart';
import '../models/print_history_model.dart';

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
                  : 'Failed to load page.';
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
        _pageError = 'Page load timed out. Check your internet connection.';
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
      if (totalHeight <= 0) return;

      final viewHeight = MediaQuery.of(context).size.height;
      _totalPages = min((totalHeight / viewHeight).ceil(), 8);

      final boundary =
          _repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

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
      await file.writeAsBytes(await pdf.save(), flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Web Print',
          type: 'pdf',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
          pages: _totalPages,
        ),
      );

      unawaited(
        Printing.layoutPdf(
          name: 'web_page.pdf',
          onLayout: (_) async => pdf.save(),
        ).timeout(const Duration(seconds: 20)).catchError((error) {
          debugPrint('Web page print dialog failed: $error');
          return false;
        }),
      );
    } catch (e) {
      debugPrint('Print error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pageError = 'Print failed.';
        });
      }
    }

    if (mounted) {
      setState(() => _isPrinting = false);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const Expanded(
                    child: Text(
                      'Web Print',
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
                          color: Color(0xFF2F80ED)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _loadUrl(),
                          decoration: const InputDecoration(
                            hintText: 'Paste or type a URL',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadUrl,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        color: const Color(0xFF2F80ED),
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
                          opacity: _isPrinting ? 0.0 : 1.0,
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
          if (_isLoading) const Center(child: CircularProgressIndicator()),
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
                      label: const Text('Retry'),
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
                      'Preparing page $_currentPage of $_totalPages',
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
              label: const Text(
                'Print Full Page',
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
              onPressed: _isPrinting ? null : _printFullPage,
            ),
          ),
        ),
      ),
    );
  }
}
