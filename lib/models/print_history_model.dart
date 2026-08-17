class PrintHistory {
  const PrintHistory({
    this.id,
    required this.title,
    required this.type,
    required this.filePath,
    required this.createdAt,
    this.pages,
  });

  final int? id;
  final String title;
  final String type;
  final String filePath;
  final String createdAt;
  final int? pages;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'file_path': filePath,
      'created_at': createdAt,
      'pages': pages,
    };
  }

  factory PrintHistory.fromMap(Map<String, Object?> map) {
    return PrintHistory(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      type: (map['type'] as String?) ?? '',
      filePath: (map['file_path'] as String?) ?? '',
      createdAt: (map['created_at'] as String?) ?? '',
      pages: map['pages'] as int?,
    );
  }
}
