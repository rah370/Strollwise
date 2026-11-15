import '../../../shared/models/report.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/zone_place_ui.dart';
import 'feed_zone_copy.dart';

sealed class FeedEntry {
  const FeedEntry();
}

class FeedMicroPost extends FeedEntry {
  const FeedMicroPost({
    required this.report,
    required this.replies,
    this.zone,
  });

  final ReportModel report;
  final ZoneModel? zone;
  final List<FeedReply> replies;
}

class FeedPulse extends FeedEntry {
  const FeedPulse({
    required this.zone,
    required this.replies,
  });

  final ZoneModel zone;
  final List<FeedReply> replies;
}

class FeedReply {
  const FeedReply({
    required this.authorHandle,
    required this.text,
    required this.createdAt,
  });

  final String authorHandle;
  final String text;
  final DateTime createdAt;
}

String feedAuthorHandle(ReportModel report) {
  final handle = report.authorHandle?.trim();
  if (handle != null && handle.startsWith('@') && !handle.contains('@', 1)) {
    return handle;
  }
  final kind = (report.authorKind ?? 'local').toLowerCase();
  return kind == 'visitor' ? '@visitor' : '@local';
}

String feedPostBody(ReportModel report) {
  final note = report.note?.trim();
  if (note != null && note.isNotEmpty) return note;
  if (report.tags.isNotEmpty) {
    final mood = report.tags
        .where((tag) => tag != 'public' && tag != 'anonymous')
        .map((tag) => tag.replaceAll('_', ' '))
        .take(3)
        .join(' · ');
    if (mood.isNotEmpty) return mood;
  }
  return 'New community tag';
}

String feedZonePillLabel(ZoneModel? zone) {
  if (zone == null) return 'Nearby zone';
  return '${zoneDisplayTitle(zone)} · ${feedCrowdLabel(zone)}';
}

bool reportMatchesChip(ReportModel report, String chip) {
  switch (chip.toLowerCase()) {
    case 'food':
      return _haystack(report).contains('food') ||
          _haystack(report).contains('cafe') ||
          _haystack(report).contains('coffee');
    case 'crowd':
      return _haystack(report).contains('crowd') ||
          _haystack(report).contains('busy') ||
          _haystack(report).contains('calm');
    case 'safety':
      return _haystack(report).contains('safety') ||
          _haystack(report).contains('caution');
    default:
      return true;
  }
}

String _haystack(ReportModel report) {
  return '${report.category} ${report.tags.join(' ')} ${report.note ?? ''}'
      .toLowerCase();
}

ZoneModel? zoneForReport(ReportModel report, List<ZoneModel> zones) {
  if (zones.isEmpty) return null;
  final lat = report.cellLat;
  final lng = report.cellLng;
  if (lat == null || lng == null) return zones.first;
  ZoneModel best = zones.first;
  var bestDist = _sq(lat - best.centroidLat) + _sq(lng - best.centroidLng);
  for (final zone in zones.skip(1)) {
    final dist =
        _sq(lat - zone.centroidLat) + _sq(lng - zone.centroidLng);
    if (dist < bestDist) {
      best = zone;
      bestDist = dist;
    }
  }
  return best;
}

double _sq(double value) => value * value;

/// Threads-style stream: micro-posts grouped by cell, with a Live Zone Pulse
/// after the first post and every three posts after that.
List<FeedEntry> buildMixedFeed({
  required List<ReportModel> reports,
  required List<ZoneModel> zones,
  String chip = 'Nearby',
  Set<String> followedZoneIds = const {},
}) {
  final filtered = reports.where((report) {
    if (!reportMatchesChip(report, chip)) return false;
    if (chip.toLowerCase() != 'following') return true;
    if (followedZoneIds.isEmpty) return false;
    final zone = zoneForReport(report, zones);
    return zone != null && followedZoneIds.contains(zone.zoneId);
  }).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final grouped = <String, List<ReportModel>>{};
  for (final report in filtered) {
    grouped.putIfAbsent(report.h3Index, () => []).add(report);
  }

  final posts = <FeedMicroPost>[];
  for (final group in grouped.values) {
    group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final parent = group.first;
    final zone = zoneForReport(parent, zones);
    final replies = group
        .skip(1)
        .where((item) => (item.note ?? '').trim().isNotEmpty)
        .toList()
        .reversed
        .take(2)
        .map(
          (item) => FeedReply(
            authorHandle: feedAuthorHandle(item),
            text: feedPostBody(item),
            createdAt: item.createdAt,
          ),
        )
        .toList();
    posts.add(FeedMicroPost(report: parent, zone: zone, replies: replies));
  }
  posts.sort((a, b) => b.report.createdAt.compareTo(a.report.createdAt));
  final parentIds = {for (final post in posts) post.report.id};

  final pulseZones = [...zones];
  if (chip.toLowerCase() == 'following' && followedZoneIds.isNotEmpty) {
    pulseZones.retainWhere((zone) => followedZoneIds.contains(zone.zoneId));
  }

  if (posts.isEmpty) {
    return [
      for (final zone in pulseZones.take(8))
        FeedPulse(
          zone: zone,
          replies: _repliesForZone(zone, filtered, zones, parentIds),
        ),
    ];
  }

  final usedPulseIds = <String>{};
  final mixed = <FeedEntry>[];
  var sincePulse = 0;
  var pulseIndex = 0;

  void addPulse() {
    while (pulseIndex < pulseZones.length) {
      final zone = pulseZones[pulseIndex++];
      if (usedPulseIds.contains(zone.zoneId)) continue;
      usedPulseIds.add(zone.zoneId);
      mixed.add(
        FeedPulse(
          zone: zone,
          replies: _repliesForZone(zone, filtered, zones, parentIds),
        ),
      );
      sincePulse = 0;
      return;
    }
  }

  for (var i = 0; i < posts.length; i++) {
    mixed.add(posts[i]);
    sincePulse += 1;
    final shouldPulse = mixed.whereType<FeedMicroPost>().length == 1 ||
        sincePulse >= 3;
    if (shouldPulse) addPulse();
  }

  return mixed;
}

List<FeedReply> _repliesForZone(
  ZoneModel zone,
  List<ReportModel> reports,
  List<ZoneModel> zones,
  Set<String> excludeIds,
) {
  return reports
      .where((report) {
        if (excludeIds.contains(report.id)) return false;
        if ((report.note ?? '').trim().isEmpty) return false;
        return zoneForReport(report, zones)?.zoneId == zone.zoneId;
      })
      .take(2)
      .map(
        (report) => FeedReply(
          authorHandle: feedAuthorHandle(report),
          text: feedPostBody(report),
          createdAt: report.createdAt,
        ),
      )
      .toList();
}

String feedTimeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return 'Earlier';
}
