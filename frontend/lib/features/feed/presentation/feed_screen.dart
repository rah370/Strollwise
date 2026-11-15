import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/brand.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/notifications/app_notification_sheet.dart';
import '../../../shared/notifications/app_notifications.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/traveler_gradient.dart';
import '../../../shared/zone_validation_metrics.dart';
import 'feed_cards.dart';
import 'feed_stream.dart';

/// Mixed micro-post + Live Zone Pulse stream (Threads-style, not zone cards only).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  static const _filters = [
    'Nearby',
    'Following',
    'Food',
    'Crowd',
    'Safety',
  ];

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  static const _backgroundRefreshInterval = Duration(seconds: 50);

  Timer? _backgroundRefresh;
  final _liked = <String>{};

  @override
  void initState() {
    super.initState();
    _backgroundRefresh = Timer.periodic(_backgroundRefreshInterval, (_) {
      if (!mounted) return;
      ref.invalidate(zoneFeedProvider);
      ref.invalidate(feedProvider);
    });
  }

  @override
  void dispose() {
    _backgroundRefresh?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.refresh(zoneFeedProvider.future),
      ref.refresh(feedProvider.future),
    ]);
  }

  void _openZoneOnExplore(ZoneModel zone) {
    ref.read(zoneValidationLiveProvider.notifier).state = null;
    final enriched = enrichZoneForAreaCard(zone);
    final focus = _mapFocusForZone(enriched);
    ref.read(selectedZoneProvider.notifier).state = enriched;
    ref.read(zoneLookupLocationProvider.notifier).state = focus;
    ref.read(exploreFocusLocationProvider.notifier).state = focus;
    ref.invalidate(selectedZoneDetailProvider);
    context.go('/explore');
  }

  void _openAddTag({ZoneModel? zone}) {
    if (zone != null) {
      final focus = _mapFocusForZone(zone);
      ref.read(exploreFocusLocationProvider.notifier).state = focus;
      ref.read(selectedZoneProvider.notifier).state = zone;
    }
    context.go('/add-tag');
  }

  static LatLng _mapFocusForZone(ZoneModel zone) {
    if (zone.centroidLat != 0.0 || zone.centroidLng != 0.0) {
      return LatLng(zone.centroidLat, zone.centroidLng);
    }
    final ring = zone.boundary;
    if (ring.length >= 3) {
      final lng =
          ring.map((point) => point[0]).reduce((a, b) => a + b) / ring.length;
      final lat =
          ring.map((point) => point[1]).reduce((a, b) => a + b) / ring.length;
      return LatLng(lat, lng);
    }
    return LatLng(zone.centroidLat, zone.centroidLng);
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zoneFeedProvider);
    final activity = ref.watch(feedProvider);
    final selectedChip = ref.watch(zoneFeedChipProvider);
    final zoneDataNotice = ref.watch(zoneDataNoticeProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final savedZones = ref.watch(savedZonesProfileProvider).valueOrNull ?? [];
    final followedIds = savedZones.map((zone) => zone.zoneId).toSet();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: feedMint,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
                    child: Row(
                      children: [
                        const StrollWiseBrandMark(size: 34),
                        const Spacer(),
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => showAppNotificationSheet(context, ref),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Badge(
                                isLabelVisible: unread > 0,
                                smallSize: 8,
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 22,
                                  color: feedInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FeedFilterRow(
                    selectedLabel: selectedChip,
                    labels: FeedScreen._filters,
                    onSelected: (label) {
                      ref.read(zoneFeedChipProvider.notifier).state = label;
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (zoneDataNotice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _FeedCacheNotice(message: zoneDataNotice),
            ),
          Expanded(
            child: zonesAsync.when(
              data: (zones) {
                return activity.when(
                  data: (reports) {
                    final entries = buildMixedFeed(
                      reports: reports,
                      zones: zones,
                      chip: selectedChip,
                      followedZoneIds: followedIds,
                    );
                    return RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: entries.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                FeedComposerBar(onAddTag: (_) => _openAddTag()),
                                const SizedBox(height: 24),
                                EmptyStateCard(
                                  message: selectedChip == 'Following'
                                      ? 'Save a zone on Explore to follow it here.'
                                      : 'No tags match this filter yet. Pull to refresh.',
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: entries.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return FeedComposerBar(
                                    onAddTag: (_) => _openAddTag(),
                                  );
                                }
                                final entry = entries[index - 1];
                                if (entry is FeedMicroPost) {
                                  final zone = entry.zone;
                                  return FeedMicroPostCard(
                                    post: entry,
                                    liked: _liked.contains(entry.report.id),
                                    onOpenMap: () {
                                      if (zone != null) {
                                        _openZoneOnExplore(zone);
                                      }
                                    },
                                    onAddTag: () => _openAddTag(zone: zone),
                                    onToggleLike: () {
                                      setState(() {
                                        if (_liked.contains(entry.report.id)) {
                                          _liked.remove(entry.report.id);
                                        } else {
                                          _liked.add(entry.report.id);
                                        }
                                      });
                                    },
                                  );
                                }
                                if (entry is FeedPulse) {
                                  return FeedPulseCard(
                                    pulse: entry,
                                    onOpenMap: () =>
                                        _openZoneOnExplore(entry.zone),
                                    onAddTag: () =>
                                        _openAddTag(zone: entry.zone),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                    );
                  },
                  loading: LoadingSkeleton.new,
                  error: (error, _) => _ErrorRefresh(
                    message: error.toString(),
                    onRefresh: _refreshAll,
                  ),
                );
              },
              loading: LoadingSkeleton.new,
              error: (error, _) => _ErrorRefresh(
                message: error.toString(),
                onRefresh: _refreshAll,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRefresh extends StatelessWidget {
  const _ErrorRefresh({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 48),
        children: [EmptyStateCard(message: message)],
      ),
    );
  }
}

class _FeedCacheNotice extends StatelessWidget {
  const _FeedCacheNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0A127)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.offline_bolt_rounded,
            size: 17,
            color: Color(0xFFB7791F),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedFilterRow extends StatelessWidget {
  const _FeedFilterRow({
    required this.selectedLabel,
    required this.labels,
    required this.onSelected,
  });

  final String selectedLabel;
  final List<String> labels;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            _FilterPill(
              label: labels[i],
              selected: labels[i] == selectedLabel,
              onTap: () => onSelected(labels[i]),
            ),
            if (i != labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F766E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}
