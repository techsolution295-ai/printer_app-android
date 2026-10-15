import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';

import '../ads/ad_service.dart';
import '../ads/banner_ad_widget.dart';
import '../l10n/labels.dart';
import '../printables/printable_item.dart';
import '../widgets/printable_thumb.dart';
import '../widgets/pro_crown_icon.dart';
import 'printable_detail_screen.dart';

class PrintablesCategoryScreen extends StatelessWidget {
  const PrintablesCategoryScreen({super.key, required this.category});

  final PrintableCategory category;

  void _openItem(BuildContext context, PrintableItem item) {
    AdService.instance.showSelectInterstitialThen(() async {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PrintableDetailScreen(item: item)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          localizedCategory(context, category.title),
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
            margin: EdgeInsets.fromLTRB(12, 0, 12, 8),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: category.items.length,
              itemBuilder: (context, index) {
                final item = category.items[index];
                return GestureDetector(
                  onTap: () => _openItem(context, item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PrintableThumb(url: item.previewUrl),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F3A45),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
