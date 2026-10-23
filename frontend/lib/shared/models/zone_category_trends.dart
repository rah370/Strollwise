class CategoryTrendModel {
  CategoryTrendModel({
    required this.category,
    required this.label,
    required this.currentCount,
    required this.previousCount,
    required this.delta,
    required this.growing,
  });

  final String category;
  final String label;
  final int currentCount;
  final int previousCount;
  final int delta;
  final bool growing;

  factory CategoryTrendModel.fromJson(Map<String, dynamic> json) {
    return CategoryTrendModel(
      category: (json['category'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      currentCount: (json['current_count'] as num?)?.toInt() ?? 0,
      previousCount: (json['previous_count'] as num?)?.toInt() ?? 0,
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      growing: json['growing'] == true,
    );
  }
}

class ZoneCategoryTrendsModel {
  ZoneCategoryTrendsModel({
    required this.zoneId,
    required this.windowDays,
    required this.currentTotal,
    required this.previousTotal,
    required this.enoughData,
    required this.minSample,
    this.peakTimeLabel,
    this.categories = const [],
  });

  final String zoneId;
  final int windowDays;
  final int currentTotal;
  final int previousTotal;
  final bool enoughData;
  final int minSample;
  final String? peakTimeLabel;
  final List<CategoryTrendModel> categories;

  factory ZoneCategoryTrendsModel.fromJson(Map<String, dynamic> json) {
    return ZoneCategoryTrendsModel(
      zoneId: (json['zone_id'] ?? '').toString(),
      windowDays: (json['window_days'] as num?)?.toInt() ?? 30,
      currentTotal: (json['current_total'] as num?)?.toInt() ?? 0,
      previousTotal: (json['previous_total'] as num?)?.toInt() ?? 0,
      enoughData: json['enough_data'] == true,
      minSample: (json['min_sample'] as num?)?.toInt() ?? 8,
      peakTimeLabel: json['peak_time_label'] as String?,
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CategoryTrendModel.fromJson)
          .toList(),
    );
  }
}
