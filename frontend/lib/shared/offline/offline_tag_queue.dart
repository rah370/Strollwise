/// Tags saved on the phone while the API cannot be reached.
library;

import 'dart:convert';

import 'package:h3_flutter/h3_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const offlineTagQueueKey = 'strollwise.offline_tag_queue';

class OfflineQueuedTag {
  const OfflineQueuedTag({
    required this.id,
    required this.h3Index,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.tags,
    required this.taggedAt,
    this.note,
  });

  final String id;
  final String h3Index;
  final double latitude;
  final double longitude;
  final String category;
  final List<String> tags;
  final String? note;
  final DateTime taggedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'h3_index': h3Index,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'tags': tags,
      'note': note,
      'tagged_at': taggedAt.toUtc().toIso8601String(),
    };
  }

  factory OfflineQueuedTag.fromJson(Map<String, dynamic> json) {
    return OfflineQueuedTag(
      id: (json['id'] ?? '').toString(),
      h3Index: (json['h3_index'] ?? '').toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: (json['category'] ?? '').toString(),
      tags: [
        for (final tag in (json['tags'] as List?) ?? const []) tag.toString(),
      ],
      note: json['note']?.toString(),
      taggedAt: DateTime.tryParse((json['tagged_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }
}

class OfflineTagQueue {
  static Future<List<OfflineQueuedTag>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(offlineTagQueueKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          if (item is Map) OfflineQueuedTag.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<int> length() async => (await load()).length;

  /// One queued tag per map cell. A second tag in the same cell replaces it.
  static Future<OfflineQueuedTag> enqueue({
    required double latitude,
    required double longitude,
    required String category,
    required List<String> tags,
    String? note,
    DateTime? taggedAt,
  }) async {
    final h3Index = _cellIndex(latitude, longitude);
    final item = OfflineQueuedTag(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      h3Index: h3Index,
      latitude: latitude,
      longitude: longitude,
      category: category,
      tags: tags,
      note: note,
      taggedAt: (taggedAt ?? DateTime.now()).toUtc(),
    );
    final current = await load();
    final next = [
      for (final existing in current)
        if (existing.h3Index != h3Index) existing,
      item,
    ];
    await _save(next);
    return item;
  }

  static Future<void> remove(String id) async {
    final current = await load();
    await _save([for (final item in current) if (item.id != id) item]);
  }

  static Future<void> _save(List<OfflineQueuedTag> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      offlineTagQueueKey,
      jsonEncode([for (final item in items) item.toJson()]),
    );
  }

  static String _cellIndex(double latitude, double longitude) {
    try {
      final h3 = const H3Factory().load();
      return h3
          .geoToCell(GeoCoord(lat: latitude, lon: longitude), 8)
          .toString();
    } catch (_) {
      return '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    }
  }
}
