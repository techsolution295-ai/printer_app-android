import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';

import '../ads/ad_service.dart';
import '../ads/banner_ad_widget.dart';
import '../l10n/labels.dart';
import '../printables/printable_item.dart';
import '../printables/printables_service.dart';
import '../widgets/printable_thumb.dart';
import '../widgets/printables_skeleton.dart';
import '../widgets/pro_crown_icon.dart';
import 'printable_detail_screen.dart';
import 'printables_category_screen.dart';

class PrintablesScreen extends StatefulWidget {
  const PrintablesScreen({super.key});

  @override
  State<PrintablesScreen> createState() => _PrintablesScreenState();
}

class _PrintablesScreenState extends State<PrintablesScreen> {
  static const _title = Color(0xFF1C1C1E);
  static const _primary = AppTheme.actionColor;

  late Future<PrintablesCatalog> _future;

  @override
  void initState() {
    super.initState();
    _future = PrintablesService.instance.loadCatalog();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = PrintablesService.instance.loadCatalog(forceRefresh: true);
    });
    await _future;
  }

  void _openItem(PrintableItem item) {
    AdService.instance.showSelectInterstitialThen(() async {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PrintableDetailScreen(item: item)),
      );
    });
  }

  void _openCategory(PrintableCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrintablesCategoryScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'printables'.tr(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _title,
            letterSpacing: -0.3,
          ),
        ),
        actions: const [
          ProAppBarButton(),
        ],
      ),
      body: Column(
        children: [
          const BannerAdWidget(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 4),
          ),
          Expanded(
            child: FutureBuilder<PrintablesCatalog>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const PrintablesSkeleton();
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 40,
                            color: Color(0xFFA0A8B3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'load_printables_failed'.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _title,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _refresh,
                            child: Text('retry'.tr()),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final categories = snapshot.data!.categories;
                return RefreshIndicator(
                  color: _primary,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 28),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      return _CategoryRow(
                        category: categories[index],
                        onSeeAll: () => _openCategory(categories[index]),
                        onItemTap: _openItem,
                      );
                    },
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onSeeAll,
    required this.onItemTap,
  });

  final PrintableCategory category;
  final VoidCallback onSeeAll;
  final ValueChanged<PrintableItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final previewItems = category.items.take(8).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    localizedCategory(context, category.title),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'see_all'.tr(namedArgs: {'count': '${category.count}'}),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.actionColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: previewItems.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = previewItems[index];
                return GestureDetector(
                  onTap: () => onItemTap(item),
                  child: PrintableThumb(
                    url: item.previewUrl,
                    width: 118,
                    height: 168,
                    borderRadius: 10,
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
