class PrintableItem {
  const PrintableItem({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.fileUrl,
    this.fileType = 'image',
    this.source,
  });

  final String id;
  final String title;
  final String previewUrl;
  final String fileUrl;

  /// `image` or `pdf`
  final String fileType;
  final String? source;

  bool get isPdf => fileType.toLowerCase() == 'pdf';

  factory PrintableItem.fromJson(Map<String, dynamic> json) {
    return PrintableItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Printable',
      previewUrl: json['previewUrl'] as String? ?? '',
      fileUrl: json['fileUrl'] as String? ?? json['previewUrl'] as String? ?? '',
      fileType: json['fileType'] as String? ?? 'image',
      source: json['source'] as String?,
    );
  }
}

class PrintableCategory {
  const PrintableCategory({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<PrintableItem> items;

  int get count => items.length;

  factory PrintableCategory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return PrintableCategory(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Category',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(PrintableItem.fromJson)
          .where((item) => item.previewUrl.isNotEmpty)
          .toList(),
    );
  }
}

class PrintablesCatalog {
  const PrintablesCatalog({
    required this.version,
    required this.categories,
  });

  final int version;
  final List<PrintableCategory> categories;

  factory PrintablesCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['categories'] as List<dynamic>? ?? const [];
    return PrintablesCatalog(
      version: json['version'] as int? ?? 1,
      categories: raw
          .whereType<Map<String, dynamic>>()
          .map(PrintableCategory.fromJson)
          .where((category) => category.items.isNotEmpty)
          .toList(),
    );
  }
}
