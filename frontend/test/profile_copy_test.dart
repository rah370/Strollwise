import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/features/profile/profile_copy.dart';
import 'package:strollwise/shared/models/report.dart';
import 'package:strollwise/shared/models/user_contributions.dart';
import 'package:strollwise/shared/models/user_me.dart';

ReportModel _report({
  required List<String> tags,
  String category = 'food',
  String? visibility,
  String? note,
}) {
  return ReportModel(
    id: '1',
    h3Index: 'abc',
    category: category,
    tags: tags,
    note: note,
    createdAt: DateTime.utc(2026, 1, 1),
    visibilityStatus: visibility,
  );
}

void main() {
  test('submitted equals approved + pending + closed statuses', () {
    final stats = UserContributionStatsModel(
      submitted: 9,
      approved: 4,
      pending: 1,
      rejected: 3,
      flagged: 1,
    );
    expect(stats.closedCount, 4);
    expect(stats.accountedCount, 9);
    expect(
      statsRemainderCopy(stats),
      '4 tags are rejected, flagged, or hidden. They still count as submitted.',
    );
  });

  test('place names replace generic tag titles', () {
    final generic = presentProfileTag(
      _report(tags: ['Neighborhood Favorite']),
      placeName: 'IT Park',
      neighborhood: 'Cebu City',
    );
    expect(generic.title, 'IT Park');
    expect(generic.subtitle, 'Food · Cebu City');

    final distinctive = presentProfileTag(
      _report(tags: ['Joe\'s BBQ', 'Street Food']),
      neighborhood: 'Cebu City',
    );
    expect(distinctive.title, "Joe's BBQ");
  });

  test('status labels map visibility including rejected remainder', () {
    expect(tagStatusKind('visible'), TagStatusKind.approved);
    expect(tagStatusLabel(TagStatusKind.pending), 'Pending');
    expect(tagStatusLabel(TagStatusKind.rejected), 'Rejected');
    expect(
      matchesTagFilter(_report(tags: ['x'], visibility: 'removed'), TagFilter.rejected),
      isTrue,
    );
    expect(
      matchesTagFilter(_report(tags: ['x'], visibility: 'flagged'), TagFilter.rejected),
      isTrue,
    );
    expect(
      matchesTagFilter(_report(tags: ['x'], visibility: 'visible'), TagFilter.approved),
      isTrue,
    );
  });

  test('next milestone uses Local Guide then Community Mapper', () {
    final early = nextMilestone(4);
    expect(early.label, 'Local Guide');
    expect(early.target, 5);
    expect(early.detail, '4 of 5 approved tags. 1 more to go.');

    final later = nextMilestone(6);
    expect(later.label, 'Community Mapper');
    expect(later.target, 25);
  });

  test('verified mark copy distinguishes operators from research consent', () {
    final user = UserMeModel(
      email: 'a@b.com',
      travelerType: 'local',
      isAdmin: false,
      acceptedResearchConsent: true,
    );
    expect(showsVerifiedMark(user), isTrue);
    expect(
      verifiedBadgeExplanation(isAdmin: false, researchConsent: true),
      contains('research'),
    );
    expect(
      verifiedBadgeExplanation(isAdmin: true, researchConsent: false),
      contains('operator'),
    );
  });
}
