import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/report.dart';
import '../../../shared/models/user_contributions.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/traveler_gradient.dart';
import '../profile_copy.dart';
import 'profile_actions.dart';
import 'profile_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  TagFilter _previewFilter = TagFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ZoneCatalog.ensureLoaded());
      final token = ref.read(authTokenProvider);
      if (token == null || token == 'demo-token-local') return;
      ref.invalidate(userMeProvider);
      unawaited(ref.read(userContributionsProvider.notifier).refresh());
    });
  }

  void _openTags([TagFilter? filter]) {
    final selected = filter ?? _previewFilter;
    final query = tagFilterQuery(selected);
    context.push('/profile/tags?status=$query');
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authUserEmailProvider);
    final token = ref.watch(authTokenProvider);
    final isDemo = token == null || token == 'demo-token-local';
    final userMe = ref.watch(userMeProvider);
    final contributions = ref.watch(userContributionsProvider);
    final visits = ref.watch(ownVisitHistoryProvider);
    final mapLocation = ref.watch(currentUserLocationProvider);

    final user = userMe.maybeWhen(data: (u) => u, orElse: () => null);
    final displayName = userMe.maybeWhen(
      data: (u) =>
          (u?.displayName != null && u!.displayName!.trim().isNotEmpty)
          ? u.displayName!.trim()
          : displayNameFromEmail(u?.email ?? email),
      orElse: () => displayNameFromEmail(email),
    );
    final locationLine = profileLocationLine(user);
    final stats = contributions.maybeWhen(
      data: (c) => c?.stats,
      orElse: () => null,
    );
    final contributorLabel = isDemo
        ? '—'
        : contributions.maybeWhen(
            data: (c) => c?.contributorLabel ?? 'New to sharing',
            loading: () => 'Loading…',
            orElse: () => 'Loading…',
          );
    final recent = contributions.maybeWhen(
      data: (c) => c?.recentReports ?? const <ReportModel>[],
      orElse: () => const <ReportModel>[],
    );
    final badges = contributions.maybeWhen(
      data: (c) => c?.badges ?? const <ProfileBadgeModel>[],
      orElse: () => const <ProfileBadgeModel>[],
    );
    final showVerified = showsVerifiedMark(user);
    final previewStats =
        stats ??
        UserContributionStatsModel(submitted: 0, approved: 0, pending: 0);
    final previewTags = recent
        .where((r) => matchesTagFilter(r, _previewFilter))
        .take(3)
        .toList();
    final earnedKeys = badges.map((b) => b.key).toSet();
    final earnedBadges = kProfileBadgeCatalog
        .where((b) => earnedKeys.contains(b.key))
        .toList();
    final visitCount = visits.maybeWhen(data: (p) => p.length, orElse: () => 0);
    final locationLabel = exploreLocationLabel(
      lat: mapLocation?.latitude ?? user?.manualMapLat,
      lng: mapLocation?.longitude ?? user?.manualMapLng,
    );
    final approved = previewStats.approved;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryAction,
          onRefresh: () => refreshProfileData(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
                            letterSpacing: -0.4,
                            height: 1.1,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: () => context.push('/profile/settings'),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              if (isDemo)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: DemoSessionCallout(
                      onSignIn: () {
                        if (context.mounted) context.go('/auth');
                      },
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, isDemo ? 12 : 16, 20, 88),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileIdentityHeader(
                        displayName: displayName,
                        locationLine: locationLine,
                        contributorLabel: contributorLabel,
                        showVerified: showVerified,
                        onEdit: isDemo ? null : () => editProfile(context, ref),
                        onVerifiedTap: showVerified
                            ? () => showVerifiedExplanationDialog(
                                context,
                                isAdmin: user?.isAdmin == true,
                                researchConsent:
                                    user?.acceptedResearchConsent == true,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      ProfileStatsCard(
                        stats: previewStats,
                        onSubmittedTap: () => _openTags(TagFilter.all),
                        onApprovedTap: () => _openTags(TagFilter.approved),
                        onPendingTap: () => _openTags(TagFilter.pending),
                      ),
                      const SizedBox(height: 12),
                      NextBadgeCard(
                        milestone: nextMilestone(approved),
                        onTap: () => context.push('/profile/achievements'),
                      ),
                      const SizedBox(height: 16),
                      ProfileSectionHeader(
                        title: 'My Tags',
                        actionLabel: 'View all',
                        onAction: _openTags,
                      ),
                      const SizedBox(height: 8),
                      TagFilterBar(
                        selected: _previewFilter,
                        stats: previewStats,
                        onSelected: (filter) {
                          setState(() => _previewFilter = filter);
                        },
                      ),
                      const SizedBox(height: 8),
                      ProfilePanel(
                        child: previewTags.isEmpty
                            ? Text(
                                isDemo
                                    ? 'Sign in to see your submissions.'
                                    : 'No tags in this filter yet.',
                                style: const TextStyle(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < previewTags.length; i++) ...[
                                    ReportTagRow(
                                      report: previewTags[i],
                                      onTap: () => openReportOnExplore(
                                        ref,
                                        context,
                                        previewTags[i],
                                      ),
                                    ),
                                    if (i < previewTags.length - 1)
                                      const Divider(
                                        height: 12,
                                        color: AppColors.border,
                                      ),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      ProfileSectionHeader(
                        title: 'Your Badges',
                        actionLabel: 'See all',
                        onAction: () => context.push('/profile/achievements'),
                      ),
                      const SizedBox(height: 8),
                      ProfilePanel(
                        child: earnedBadges.isEmpty
                            ? const Text(
                                'No badges yet. Submit tags that get approved to unlock them.',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final badge in earnedBadges)
                                    ProfileBadgeChip(
                                      badge: badge,
                                      onTap: () => showBadgeSheet(
                                        context,
                                        badge,
                                        true,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      ProfileLinkRow(
                        icon: Icons.hiking_rounded,
                        title: "Places you've been",
                        subtitle: visitCount == 0
                            ? 'Your private visit history'
                            : 'Your private visit history · $visitCount pins',
                        onTap: () => context.push('/profile/visits'),
                      ),
                      const SizedBox(height: 12),
                      ExploreLocationRow(
                        cityLabel: locationLabel,
                        onChange: () =>
                            setManualLocationFromProfile(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
