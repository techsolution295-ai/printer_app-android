import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message ?? 'please_wait'.tr(context: context);
    return Center(
      child: Material(
        color: Colors.white,
        elevation: 6,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.actionColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2B3A55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppBusyOverlay extends StatelessWidget {
  const AppBusyOverlay({
    super.key,
    required this.busy,
    required this.child,
    this.message,
  });

  final bool busy;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (busy)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: const Color(0x660F172A),
                child: AppLoader(message: message),
              ),
            ),
          ),
      ],
    );
  }
}

PdfViewPinchBuilders<DefaultBuilderOptions> appPdfPinchBuilders() {
  return PdfViewPinchBuilders<DefaultBuilderOptions>(
    options: const DefaultBuilderOptions(),
    documentLoaderBuilder: (context) =>
        AppLoader(message: 'opening_pdf'.tr(context: context)),
    pageLoaderBuilder: (_) => const Center(
      child: CircularProgressIndicator(color: AppTheme.actionColor),
    ),
    errorBuilder: (context, error) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'could_not_open_pdf_short'.tr(context: context),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B3A55),
          ),
        ),
      ),
    ),
  );
}

Future<bool> openPrintLayout({
  required String name,
  required Uint8List bytes,
}) {
  return Printing.layoutPdf(
    name: name,
    onLayout: (_) async => bytes,
  );
}
