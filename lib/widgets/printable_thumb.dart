import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';

class PrintableThumb extends StatelessWidget {
  const PrintableThumb({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius = 10,
  });

  final String url;
  final double? width;
  final double? height;
  final double borderRadius;

  static const _headers = {
    'User-Agent': 'SmartPrinter/1.0',
    'Accept': 'image/*,*/*;q=0.8',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        httpHeaders: _headers,
        memCacheWidth: 600,
        placeholder: (context, url) => const ColoredBox(
          color: Color(0xFFF3F4F6),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppTheme.actionColor,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => const ColoredBox(
          color: Color(0xFFF3F4F6),
          child: Icon(Icons.broken_image_outlined, color: Color(0xFFA0A8B3)),
        ),
      ),
    );
  }
}
