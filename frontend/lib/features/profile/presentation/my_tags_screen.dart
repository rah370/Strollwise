import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/report.dart';
import '../../../shared/models/user_contributions.dart';
import '../../../shared/providers/app_providers.dart';
import '../profile_copy.dart';
import 'profile_actions.dart';
import 'profile_widgets.dart';

class MyTagsScreen extends ConsumerStatefulWidget {
  const MyTagsScreen({super.key, this.initialFilter = TagFilter.all});

  final TagFilter initialFilter;

  @override
  ConsumerState<MyTagsScreen> createState() => _MyTagsScreenState();
}

class _MyTagsScreenState extends ConsumerState<MyTagsScreen> {
  late TagFilter _filter = widget.initialFilter;

  @override
  void didUpdateWidget(MyTagsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      _filter = widget.initialFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final contributions = ref.watch(userContributionsProvider);
    final stats =
        contributions.maybeWhen(data: (c) => c?.stats, orElse: () => null) ??
        UserContributionStatsModel(submitted: 0, approved: 0, pending: 0);
    final reports = contributions.maybeWhen(
      data: (c) => c?.recentReports ?? const <ReportModel>[],
      orElse: () => const <ReportModel>[],
    );
    final filtered = reports
        .where((r) => matchesTagFilter(r, _filter))
        .toList();

    return ProfileSubpageScaffold(
      title: 'My Tags',
      body: RefreshIndicator(
        color: AppColors.primaryAction,
        onRefresh: () => refreshProfileData(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              statsRemainderCopy(stats),
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TagFilterBar(
              selected: _filter,
              stats: stats,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 12),
            if (contributions.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (filtered.isEmpty)
              ProfilePanel(
                child: Text(
                  _emptyCopy(_filter),
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ProfilePanel(
                child: Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      ReportTagRow(
                        report: filtered[i],
                        showMapLink: true,
                        onTap: () => openReportOnExplore(
                          ref,
                          context,
                          filtered[i],
                        ),
                      ),
                      if (i < filtered.length - 1)
                        const Divider(height: 12, color: AppColors.border),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Approved tags can appear on public maps after validation. '
              'Pending tags are waiting. Rejected, flagged, and hidden tags '
              'still count as submitted so the totals stay complete.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyCopy(TagFilter filter) {
    switch (filter) {
      case TagFilter.all:
        return 'No contributions yet. Add your first tag from the Add Tag tab.';
      case TagFilter.pending:
        return 'No pending tags.';
      case TagFilter.approved:
        return 'No approved tags yet.';
      case TagFilter.rejected:
        return 'No rejected, flagged, or hidden tags.';
    }
  }
}
