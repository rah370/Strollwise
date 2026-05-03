class ReportModel {
  ReportModel({
    required this.id,
    required this.h3Index,
    required this.category,
    required this.tags,
    required this.note,
    required this.createdAt,
    this.imageUrl,
  });

  final int id;
  final String h3Index;
  final String category;
  final List<String> tags;
  final String? note;
  final DateTime createdAt;
  final String? imageUrl;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as int,
      h3Index: json['h3_index'] as String,
      category: json['category'] as String,
      tags: (json['tags_json'] as List).map((e) => e as String).toList(),
      note: json['note_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      imageUrl: json['image_url'] as String?,
    );
  }
}
