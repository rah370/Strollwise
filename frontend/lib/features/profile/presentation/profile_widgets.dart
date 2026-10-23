import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/report.dart';
import '../../../shared/models/user_contributions.dart';
import '../profile_copy.dart';

BoxDecoration profilePanelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
}

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: profilePanelDecoration(),
      child: child,
    );
  }
}

class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.touristAccent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class ProfileIdentityHeader extends StatelessWidget {
  const ProfileIdentityHeader({
    super.key,
    required this.displayName,
    required this.locationLine,
    required this.contributorLabel,
    required this.showVerified,
    this.onEdit,
    this.onVerifiedTap,
  });

  final String displayName;
  final String locationLine;
  final String contributorLabel;
  final bool showVerified;
  final VoidCallback? onEdit;
  final VoidCallback? onVerifiedTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.backgroundAlt,
          child: const Icon(
            Icons.directions_walk_rounded,
            color: AppColors.mapInk,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (showVerified) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onVerifiedTap,
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
              if (locationLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  locationLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                contributorLabel,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.touristAccent,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Edit profile',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({
    super.key,
    required this.stats,
    this.onApprovedTap,
    this.onPendingTap,
    this.onSubmittedTap,
  });

  final UserContributionStatsModel stats;
  final VoidCallback? onApprovedTap;
  final VoidCallback? onPendingTap;
  final VoidCallback? onSubmittedTap;

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _StatCell(
                    value: '${stats.submitted}',
                    label: 'Submitted',
                    onTap: onSubmittedTap,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border.withValues(alpha: 0.9),
                ),
                Expanded(
                  child: _StatCell(
                    value: '${stats.approved}',
                    label: 'Approved',
                    accent: AppColors.localAccent,
                    onTap: onApprovedTap,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border.withValues(alpha: 0.9),
                ),
                Expanded(
                  child: _StatCell(
                    value: '${stats.pending}',
                    label: 'Pending',
                    accent: const Color(0xFFB45309),
                    onTap: onPendingTap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            statsRemainderCopy(stats),
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.accent = AppColors.primaryText,
    this.onTap,
  });

  final String value;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

class NextBadgeCard extends StatelessWidget {
  const NextBadgeCard({super.key, required this.milestone, this.onTap});

  final ProfileMilestone milestone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              milestone.complete
                  ? milestone.label
                  : 'Next badge: ${milestone.label}',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: milestone.progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: AppColors.primaryAction,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(milestone.progress * 100).round()}%',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              milestone.detail,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TagStatusChip extends StatelessWidget {
  const TagStatusChip({super.key, required this.status});

  final TagStatusKind status;

  @override
  Widget build(BuildContext context) {
    final color = tagStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tagStatusFill(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tagStatusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class ProfileTagRow extends StatelessWidget {
  const ProfileTagRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.category,
    this.onTap,
    this.showMapLink = false,
  });

  final String title;
  final String subtitle;
  final TagStatusKind status;
  final String category;
  final VoidCallback? onTap;
  final bool showMapLink;

  @override
  Widget build(BuildContext context) {
    final accent = tagStatusColor(status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(categoryIcon(category), size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TagStatusChip(status: status),
                      ],
                    ),
                    if (showMapLink) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'View on map',
                        style: TextStyle(
                          color: AppColors.touristAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportTagRow extends StatelessWidget {
  const ReportTagRow({
    super.key,
    required this.report,
    this.onTap,
    this.showMapLink = false,
  });

  final ReportModel report;
  final VoidCallback? onTap;
  final bool showMapLink;

  @override
  Widget build(BuildContext context) {
    final presented = presentReportWithCatalog(report);
    return ProfileTagRow(
      title: presented.title,
      subtitle: presented.subtitle,
      status: presented.status,
      category: report.category,
      onTap: onTap,
      showMapLink: showMapLink,
    );
  }
}

class TagFilterBar extends StatelessWidget {
  const TagFilterBar({
    super.key,
    required this.selected,
    required this.stats,
    required this.onSelected,
  });

  final TagFilter selected;
  final UserContributionStatsModel stats;
  final ValueChanged<TagFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = <TagFilter>[
      TagFilter.all,
      TagFilter.pending,
      TagFilter.approved,
      TagFilter.rejected,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '${tagFilterLabel(filter)} (${countForFilter(stats, filter)})',
                ),
                selected: selected == filter,
                onSelected: (_) => onSelected(filter),
                selectedColor: AppColors.backgroundAlt,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: selected == filter
                      ? AppColors.mapInk
                      : AppColors.secondaryText,
                ),
                side: BorderSide(
                  color: selected == filter
                      ? AppColors.lagoon
                      : AppColors.border,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileBadgeChip extends StatelessWidget {
  const ProfileBadgeChip({
    super.key,
    required this.badge,
    this.onTap,
    this.earned = true,
  });

  final ProfileBadgeInfo badge;
  final VoidCallback? onTap;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final style = badgeStyleFor(badge.key);
    final bg = earned ? style.$1 : AppColors.residentialFill;
    final fg = earned ? style.$2 : AppColors.mutedText;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badge.icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                badge.label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileLinkRow extends StatelessWidget {
  const ProfileLinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.backgroundAlt,
          child: Icon(icon, color: AppColors.mapInk),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
            fontSize: 12.5,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.mutedText,
        ),
        onTap: onTap,
      ),
    );
  }
}

class ExploreLocationRow extends StatelessWidget {
  const ExploreLocationRow({
    super.key,
    required this.cityLabel,
    required this.onChange,
  });

  final String cityLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: AppColors.mapInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Explore location\n',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  TextSpan(
                    text: cityLabel,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.touristAccent,
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class DemoSessionCallout extends StatelessWidget {
  const DemoSessionCallout({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign in to load your tags, badges, and saved places.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onSignIn,
              child: const Text('Sign in or register'),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSubpageScaffold extends StatelessWidget {
  const ProfileSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: actions,
      ),
      body: body,
    );
  }
}
