import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/zone_category_trends.dart';
import '../trends_copy.dart';

BoxDecoration trendsPanelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
}

class TrendsPanel extends StatelessWidget {
  const TrendsPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: trendsPanelDecoration(),
      child: child,
    );
  }
}

class TrendsSectionHeader extends StatelessWidget {
  const TrendsSectionHeader({
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

class TrendsIdentityHeader extends StatelessWidget {
  const TrendsIdentityHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.windowLabel,
    required this.tagCount,
    required this.peakLabel,
  });

  final String title;
  final String subtitle;
  final String windowLabel;
  final int tagCount;
  final String peakLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trends',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
            letterSpacing: -0.3,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          windowLabel,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 14),
        TrendsPanel(
          child: Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  value: '$tagCount',
                  label: 'Reported zone tags',
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.border),
              Expanded(
                child: _HeaderStat(
                  value: peakLabel,
                  label: 'Reported peak period',
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.value,
    required this.label,
    this.compact = false,
  });

  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: compact ? 16 : 22,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
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
  }
}

class TrendsTabBar extends StatelessWidget {
  const TrendsTabBar({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final TrendsSection section;
  final ValueChanged<TrendsSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TrendsSection>(
      segments: const [
        ButtonSegment(
          value: TrendsSection.forYou,
          label: Text('For you'),
        ),
        ButtonSegment(
          value: TrendsSection.vibes,
          label: Text('Vibes'),
        ),
        ButtonSegment(
          value: TrendsSection.routes,
          label: Text('Routes'),
        ),
      ],
      selected: {section},
      onSelectionChanged: (values) => onChanged(values.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.mapInk;
          }
          return AppColors.mutedText;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryAction.withValues(alpha: 0.22);
          }
          return Colors.white;
        }),
      ),
    );
  }
}

class VibeCard extends StatelessWidget {
  const VibeCard({super.key, required this.vibe, required this.onTap});

  final TrendVibe vibe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: vibe.fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: vibe.accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(vibe.icon, color: vibe.accent, size: 22),
              const SizedBox(height: 8),
              Text(
                vibe.title,
                style: TextStyle(
                  color: vibe.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                vibe.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VibeCardGrid extends StatelessWidget {
  const VibeCardGrid({
    super.key,
    required this.vibes,
    required this.onTap,
  });

  final List<TrendVibe> vibes;
  final ValueChanged<TrendVibe> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final vibe in vibes)
              SizedBox(
                width: width,
                child: VibeCard(vibe: vibe, onTap: () => onTap(vibe)),
              ),
          ],
        );
      },
    );
  }
}

class CategoryTrendRow extends StatelessWidget {
  const CategoryTrendRow({
    super.key,
    required this.row,
    required this.windowDays,
  });

  final CategoryTrendModel row;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    final color = row.growing ? AppColors.localAccent : AppColors.secondaryText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            row.growing ? Icons.trending_up_rounded : Icons.horizontal_rule_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.label} · ${row.currentCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  categoryTrendDetail(row, windowDays),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: AppColors.secondaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WalkingRouteCard extends StatelessWidget {
  const WalkingRouteCard({
    super.key,
    required this.route,
    required this.onStopTap,
    required this.onOpenMap,
  });

  final WalkingRoute route;
  final ValueChanged<WalkingStop> onStopTap;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return TrendsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            route.metaLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.mutedText,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < route.stops.length; i++) ...[
            InkWell(
              onTap: () => onStopTap(route.stops[i]),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.primaryAction.withValues(alpha: 0.2),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.mapInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.stops[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryText,
                            ),
                          ),
                          if (route.stops[i].address.isNotEmpty)
                            Text(
                              route.stops[i].address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedText,
                    ),
                  ],
                ),
              ),
            ),
            if (i < route.stops.length - 1)
              const Divider(height: 8, color: AppColors.border),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Explore on map'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryAction,
                foregroundColor: AppColors.mapInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
