import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../shared/models/report.dart';
import '../../shared/models/user_contributions.dart';
import '../../shared/models/user_me.dart';
import '../../shared/traveler_gradient.dart';

enum TagStatusKind { approved, pending, rejected, flagged, hidden }

enum TagFilter { all, pending, approved, rejected }

class ProfileTagPresentation {
  const ProfileTagPresentation({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final TagStatusKind status;
}

class ProfileMilestone {
  const ProfileMilestone({
    required this.label,
    required this.current,
    required this.target,
    required this.detail,
    this.complete = false,
  });

  final String label;
  final int current;
  final int target;
  final String detail;
  final bool complete;

  double get progress {
    if (target <= 0) return 1;
    return (current / target).clamp(0.0, 1.0);
  }

  int get remaining => (target - current).clamp(0, target);
}

class ProfileBadgeInfo {
  const ProfileBadgeInfo({
    required this.key,
    required this.label,
    required this.howToEarn,
    required this.earnedCopy,
    required this.icon,
  });

  final String key;
  final String label;
  final String howToEarn;
  final String earnedCopy;
  final IconData icon;
}

class ContributorMilestone {
  const ContributorMilestone({
    required this.label,
    required this.minApproved,
    required this.detail,
  });

  final String label;
  final int minApproved;
  final String detail;
}

/// Category chips from Add Tag that should not replace a real place name.
const Set<String> kGenericTagLabels = {
  'street food',
  'cafe',
  'restaurant',
  'late night',
  'photo spot',
  'landmark',
  'visitor friendly',
  'scenic',
  'neighborhood favorite',
  'budget meal',
  'worth detour',
  'calm',
  'near transit',
  'pickup point',
  'traffic',
  'easy crossing',
  'shade',
  'green space',
  'fresh air',
  'quiet walk',
  'well lit',
  'avoid late',
  'police nearby',
  'crowded exit',
  'quiet',
  'family area',
  'mostly locals',
  'side streets',
  'mall area',
  'offices',
  'busy',
  'open late',
  'study friendly',
  'student budget',
  'after class',
  'campus edge',
  'uspf campus',
  'food',
  'transport',
  'safety',
  'school',
  'other',
  'crowd',
};

const List<ProfileBadgeInfo> kProfileBadgeCatalog = [
  ProfileBadgeInfo(
    key: 'zone_scout',
    label: 'Zone Scout',
    howToEarn: 'Submit your first tag in Cebu.',
    earnedCopy: 'You submitted your first tag.',
    icon: Icons.place_outlined,
  ),
  ProfileBadgeInfo(
    key: 'food_finder',
    label: 'Food Finder',
    howToEarn: 'Get one food tag approved.',
    earnedCopy: 'You have an approved food tag on the map.',
    icon: Icons.restaurant_rounded,
  ),
  ProfileBadgeInfo(
    key: 'transport_helper',
    label: 'Transport Helper',
    howToEarn: 'Get one transport tag approved.',
    earnedCopy: 'You have an approved transport tag on the map.',
    icon: Icons.directions_bus_outlined,
  ),
  ProfileBadgeInfo(
    key: 'safety_reporter',
    label: 'Safety Reporter',
    howToEarn: 'Get one safety tag approved.',
    earnedCopy: 'You have an approved safety tag on the map.',
    icon: Icons.shield_outlined,
  ),
  ProfileBadgeInfo(
    key: 'local_guide',
    label: 'Local Guide',
    howToEarn: 'Get 5 tags approved.',
    earnedCopy: 'Five of your tags are approved.',
    icon: Icons.star_border_rounded,
  ),
];

const List<ContributorMilestone> kContributorMilestones = [
  ContributorMilestone(
    label: 'New to sharing',
    minApproved: 0,
    detail: 'You have not had a tag approved yet.',
  ),
  ContributorMilestone(
    label: 'Active contributor',
    minApproved: 1,
    detail: 'At least one approved tag.',
  ),
  ContributorMilestone(
    label: 'Community mapper',
    minApproved: 5,
    detail: 'Five or more approved tags.',
  ),
  ContributorMilestone(
    label: 'Zone champion',
    minApproved: 25,
    detail: 'Twenty-five or more approved tags.',
  ),
];

const String kProfilePrivacyCopy =
    'Public maps show aggregated neighborhood signals, not your walking trail. '
    'When you submit a tag, StrollWise stores the coordinates used to assign '
    'an H3 cell. Exact GPS is not shown to other travelers. Moderators can '
    'review cell-level tags. Visit pins stay on your account.';

const String kVisitHistoryPrivacyCopy =
    'These are private pins on your account — places you marked or tagged. '
    'They are not a live GPS trace, and other travelers cannot see them.';

TagStatusKind tagStatusKind(String? visibilityStatus) {
  switch ((visibilityStatus ?? 'visible').toLowerCase()) {
    case 'visible':
      return TagStatusKind.approved;
    case 'pending':
      return TagStatusKind.pending;
    case 'removed':
      return TagStatusKind.rejected;
    case 'flagged':
      return TagStatusKind.flagged;
    case 'hidden':
      return TagStatusKind.hidden;
    default:
      return TagStatusKind.pending;
  }
}

String tagStatusLabel(TagStatusKind kind) {
  switch (kind) {
    case TagStatusKind.approved:
      return 'Approved';
    case TagStatusKind.pending:
      return 'Pending';
    case TagStatusKind.rejected:
      return 'Rejected';
    case TagStatusKind.flagged:
      return 'Flagged';
    case TagStatusKind.hidden:
      return 'Hidden';
  }
}

Color tagStatusColor(TagStatusKind kind) {
  switch (kind) {
    case TagStatusKind.approved:
      return AppColors.localAccent;
    case TagStatusKind.pending:
      return const Color(0xFFB45309);
    case TagStatusKind.rejected:
      return AppColors.alert;
    case TagStatusKind.flagged:
      return const Color(0xFFC2410C);
    case TagStatusKind.hidden:
      return AppColors.secondaryText;
  }
}

Color tagStatusFill(TagStatusKind kind) {
  switch (kind) {
    case TagStatusKind.approved:
      return AppColors.localFill;
    case TagStatusKind.pending:
      return const Color(0xFFFFF4E5);
    case TagStatusKind.rejected:
      return AppColors.safetyFill;
    case TagStatusKind.flagged:
      return const Color(0xFFFFE9CC);
    case TagStatusKind.hidden:
      return AppColors.residentialFill;
  }
}

String categoryLabel(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return 'Food';
    case 'transport':
      return 'Transport';
    case 'safety':
      return 'Safety';
    case 'school':
      return 'School';
    case 'crowd':
      return 'Busy';
    case 'commercial':
      return 'Commercial';
    case 'residential':
      return 'Residential';
    case 'tourist':
      return 'Tourist';
    default:
      return 'Place';
  }
}

IconData categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant_rounded;
    case 'transport':
      return Icons.directions_bus_outlined;
    case 'safety':
      return Icons.shield_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'crowd':
      return Icons.groups_rounded;
    case 'commercial':
      return Icons.shopping_bag_outlined;
    case 'residential':
      return Icons.home_outlined;
    case 'tourist':
      return Icons.camera_alt_outlined;
    default:
      return Icons.place_outlined;
  }
}

bool isGenericTagLabel(String raw) {
  return kGenericTagLabels.contains(raw.trim().toLowerCase());
}

String _titleCase(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((part) {
        if (part.isEmpty) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

ProfileTagPresentation presentProfileTag(
  ReportModel report, {
  String? placeName,
  String? neighborhood,
}) {
  final status = tagStatusKind(report.visibilityStatus);
  final category = categoryLabel(report.category);
  final city = (neighborhood ?? '').trim().isNotEmpty
      ? neighborhood!.trim()
      : 'Cebu City';
  final subtitle = '$category · $city';
  final place = (placeName ?? '').trim();
  if (place.isNotEmpty) {
    return ProfileTagPresentation(
      title: place,
      subtitle: subtitle,
      status: status,
    );
  }
  final tags = report.tags
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  final distinctive = tags.where((t) => !isGenericTagLabel(t)).toList();
  if (distinctive.isNotEmpty) {
    return ProfileTagPresentation(
      title: _titleCase(distinctive.first),
      subtitle: subtitle,
      status: status,
    );
  }
  if (tags.isNotEmpty) {
    return ProfileTagPresentation(
      title: _titleCase(tags.first),
      subtitle: subtitle,
      status: status,
    );
  }
  return ProfileTagPresentation(
    title: category,
    subtitle: city,
    status: status,
  );
}

bool matchesTagFilter(ReportModel report, TagFilter filter) {
  final kind = tagStatusKind(report.visibilityStatus);
  switch (filter) {
    case TagFilter.all:
      return true;
    case TagFilter.pending:
      return kind == TagStatusKind.pending;
    case TagFilter.approved:
      return kind == TagStatusKind.approved;
    case TagFilter.rejected:
      return kind == TagStatusKind.rejected ||
          kind == TagStatusKind.flagged ||
          kind == TagStatusKind.hidden;
  }
}

int countForFilter(UserContributionStatsModel stats, TagFilter filter) {
  switch (filter) {
    case TagFilter.all:
      return stats.submitted;
    case TagFilter.pending:
      return stats.pending;
    case TagFilter.approved:
      return stats.approved;
    case TagFilter.rejected:
      return stats.closedCount;
  }
}

String tagFilterLabel(TagFilter filter) {
  switch (filter) {
    case TagFilter.all:
      return 'All';
    case TagFilter.pending:
      return 'Pending';
    case TagFilter.approved:
      return 'Approved';
    case TagFilter.rejected:
      return 'Rejected';
  }
}

TagFilter tagFilterFromQuery(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'pending':
      return TagFilter.pending;
    case 'approved':
      return TagFilter.approved;
    case 'rejected':
      return TagFilter.rejected;
    default:
      return TagFilter.all;
  }
}

String tagFilterQuery(TagFilter filter) {
  switch (filter) {
    case TagFilter.all:
      return 'all';
    case TagFilter.pending:
      return 'pending';
    case TagFilter.approved:
      return 'approved';
    case TagFilter.rejected:
      return 'rejected';
  }
}

String statsRemainderCopy(UserContributionStatsModel stats) {
  final closed = stats.closedCount;
  if (closed <= 0) {
    if (stats.submitted == stats.accountedCount) {
      return 'Submitted is Approved + Pending. Every tag keeps a status.';
    }
    return 'Submitted should equal Approved + Pending + rejected or hidden tags.';
  }
  final noun = closed == 1 ? 'tag is' : 'tags are';
  return '$closed $noun rejected, flagged, or hidden. They still count as submitted.';
}

ProfileMilestone nextMilestone(int approved) {
  if (approved < 5) {
    final remaining = 5 - approved;
    return ProfileMilestone(
      label: 'Local Guide',
      current: approved,
      target: 5,
      detail: approved == 0
          ? 'Get 5 tags approved to earn Local Guide.'
          : '$approved of 5 approved tags. $remaining more to go.',
    );
  }
  if (approved < 25) {
    final remaining = 25 - approved;
    return ProfileMilestone(
      label: 'Community Mapper',
      current: approved,
      target: 25,
      detail: '$approved of 25 approved tags. $remaining more to go.',
    );
  }
  return const ProfileMilestone(
    label: 'Zone Champion',
    current: 25,
    target: 25,
    detail: 'You hold the top contributor label.',
    complete: true,
  );
}

String displayNameFromEmail(String? email) {
  if (email == null || email.isEmpty || email == 'demo@strollwise.local') {
    return 'New Explorer';
  }
  return email.split('@').first.replaceAll('.', ' ');
}

String profileLocationLine(UserMeModel? user) {
  if (user == null) return '';
  final bits = <String>[];
  final city = user.cityOfOrigin?.trim();
  final country = user.countryOfOrigin?.trim();
  if (city != null && city.isNotEmpty) bits.add(city);
  if (country != null && country.isNotEmpty) bits.add(country);
  return bits.join(', ');
}

String userTypeLabel(String? userType, String travelerType) {
  switch ((userType ?? '').toLowerCase()) {
    case 'local_resident':
      return 'Local resident';
    case 'international_visitor':
      return 'International visitor';
    case 'domestic_traveler':
      return 'Domestic traveler';
    default:
      switch (travelerType.toLowerCase()) {
        case 'local':
          return 'Local traveler';
        case 'international':
          return 'International visitor';
        default:
          return 'Mixed traveler';
      }
  }
}

bool showsVerifiedMark(UserMeModel? user) {
  if (user == null) return false;
  return user.isAdmin || user.acceptedResearchConsent;
}

String verifiedBadgeExplanation({
  required bool isAdmin,
  required bool researchConsent,
}) {
  if (isAdmin) {
    return 'The blue check marks a StrollWise operator account.';
  }
  if (researchConsent) {
    return 'The blue check means you agreed that aggregated tags may be used for research. It is not public identity verification.';
  }
  return 'The blue check is an account mark on StrollWise.';
}

(Color, Color, IconData) badgeStyleFor(String key) {
  return switch (key) {
    'food_finder' => (
      const Color(0xFFFFF4E5),
      const Color(0xFFB7791F),
      Icons.restaurant_rounded,
    ),
    'transport_helper' => (
      const Color(0xFFF2EEFF),
      const Color(0xFF6B46C1),
      Icons.directions_bus_outlined,
    ),
    'local_guide' => (
      const Color(0xFFEEF5FF),
      const Color(0xFF3B82F6),
      Icons.star_border_rounded,
    ),
    'safety_reporter' => (
      const Color(0xFFFFF0F6),
      const Color(0xFFB83280),
      Icons.shield_outlined,
    ),
    _ => (
      const Color(0xFFE9F8EF),
      const Color(0xFF2F855A),
      Icons.place_outlined,
    ),
  };
}

String exploreLocationLabel({
  required double? lat,
  required double? lng,
}) {
  if (lat == null || lng == null) return 'Cebu City';
  final entry = ZoneCatalog.nearestEntryWithin(lat, lng, maxKm: 12);
  if (entry == null) return 'Cebu City';
  final city = entry.city.trim();
  if (city.isNotEmpty) return city;
  final name = entry.zoneName.trim();
  return name.isEmpty ? 'Cebu City' : name;
}

ProfileTagPresentation presentReportWithCatalog(ReportModel report) {
  final lat = report.cellLat;
  final lng = report.cellLng;
  ZoneCatalogEntry? entry;
  if (lat != null && lng != null) {
    entry = ZoneCatalog.nearestEntryWithin(lat, lng);
  }
  return presentProfileTag(
    report,
    placeName: entry?.zoneName,
    neighborhood: entry?.city,
  );
}
