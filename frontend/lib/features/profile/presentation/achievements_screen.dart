import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/user_contributions.dart';
import '../../../shared/providers/app_providers.dart';
import '../profile_copy.dart';
import 'profile_actions.dart';
import 'profile_widgets.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributions = ref.watch(userContributionsProvider);
    final stats =
        contributions.maybeWhen(data: (c) => c?.stats, orElse: () => null) ??
        UserContributionStatsModel(submitted: 0, approved: 0, pending: 0);
    final earnedKeys = contributions
        .maybeWhen(
          data: (c) => c?.badges ?? const <ProfileBadgeModel>[],
          orElse: () => const <ProfileBadgeModel>[],
        )
        .map((b) => b.key)
        .toSet();
    final contributorLabel = contributions.maybeWhen(
      data: (c) => c?.contributorLabel ?? 'New to sharing',
      orElse: () => 'New to sharing',
    );
    final milestone = nextMilestone(stats.approved);

    return ProfileSubpageScaffold(
      title: 'Achievements',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          NextBadgeCard(milestone: milestone),
          const SizedBox(height: 16),
          const ProfileSectionHeader(title: 'Badges'),
          const SizedBox(height: 8),
          for (final badge in kProfileBadgeCatalog) ...[
            _BadgeTile(
              badge: badge,
              earned: earnedKeys.contains(badge.key),
              onTap: () => showBadgeSheet(
                context,
                badge,
                earnedKeys.contains(badge.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          const ProfileSectionHeader(title: 'Contributor labels'),
          const SizedBox(height: 8),
          ProfilePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: $contributorLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in kContributorMilestones) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        stats.approved >= item.minApproved
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: stats.approved >= item.minApproved
                            ? AppColors.localAccent
                            : AppColors.mutedText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.label} — ${item.detail}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.earned,
    required this.onTap,
  });

  final ProfileBadgeInfo badge;
  final bool earned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = badgeStyleFor(badge.key);
    return ProfilePanel(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: CircleAvatar(
            backgroundColor: earned ? style.$1 : AppColors.residentialFill,
            child: Icon(
              badge.icon,
              color: earned ? style.$2 : AppColors.mutedText,
            ),
          ),
          title: Text(
            badge.label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: earned ? AppColors.primaryText : AppColors.secondaryText,
            ),
          ),
          subtitle: Text(
            earned ? badge.earnedCopy : badge.howToEarn,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: AppColors.secondaryText,
            ),
          ),
          trailing: Icon(
            earned ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: earned ? AppColors.localAccent : AppColors.mutedText,
          ),
        ),
      ),
    );
  }
}
