import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/models/zone_category_trends.dart';
import '../../../shared/open_area_on_explore.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/zone_place_ui.dart';
import '../trends_copy.dart';
import 'places_to_go_sheet.dart';
import 'trends_providers.dart';
import 'trends_widgets.dart';

class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({this.zoneId, super.key});

  final String? zoneId;

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  TrendsSection _section = TrendsSection.forYou;
  bool _showAllVibes = false;

  @override
  Widget build(BuildContext context) {
    final selectedZone = ref.watch(selectedZoneProvider);
    final feedAsync = ref.watch(zoneFeedProvider);
    final feedZones = feedAsync.valueOrNull ?? const <ZoneModel>[];
    final zone = _resolveZone(selectedZone, feedZones, widget.zoneId);
    final windowDays = ref.watch(trendsWindowDaysProvider);
    final trendsAsync = zone == null
        ? null
        : ref.watch(
            zoneCategoryTrendsProvider(
              TrendsWindow(zoneId: zone.zoneId, days: windowDays),
            ),
          );
    final trends = trendsAsync?.valueOrNull;
    final tagCount = trends?.currentTotal ?? zone?.reportCount ?? 0;
    final peakLabel = formatPeakPeriod(
      trends?.peakTimeLabel ?? zone?.peakTimeLabel,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryAction,
          onRefresh: () async {
            ref.invalidate(zoneFeedProvider);
            if (zone != null) {
              ref.invalidate(
                zoneCategoryTrendsProvider(
                  TrendsWindow(zoneId: zone.zoneId, days: windowDays),
                ),
              );
              ref.invalidate(zoneWalkingRouteProvider(zone));
            }
            await ref.read(zoneFeedProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              TrendsIdentityHeader(
                title: trendsZoneTitle(zone),
                subtitle: trendsZoneSubtitle(zone),
                windowLabel: zone == null
                    ? 'Choose a zone to compare recent tags'
                    : 'Last $windowDays days',
                tagCount: tagCount,
                peakLabel: peakLabel,
              ),
              const SizedBox(height: 14),
              TrendsTabBar(
                section: _section,
                onChanged: (value) => setState(() => _section = value),
              ),
              const SizedBox(height: 16),
              ..._sectionChildren(
                zone: zone,
                trends: trends,
                windowDays: windowDays,
                feedZones: feedZones,
                feedLoading: feedAsync.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sectionChildren({
    required ZoneModel? zone,
    required ZoneCategoryTrendsModel? trends,
    required int windowDays,
    required List<ZoneModel> feedZones,
    required bool feedLoading,
  }) {
    switch (_section) {
      case TrendsSection.forYou:
        return _forYou(zone, trends, windowDays, feedZones, feedLoading);
      case TrendsSection.vibes:
        return _vibes(zone);
      case TrendsSection.routes:
        return _routes(zone);
    }
  }

  List<Widget> _forYou(
    ZoneModel? zone,
    ZoneCategoryTrendsModel? trends,
    int windowDays,
    List<ZoneModel> feedZones,
    bool feedLoading,
  ) {
    final nearby = kTrendVibes.take(kDefaultVibesPreview).toList();
    return [
      const TrendsSectionHeader(title: "Explore what's nearby"),
      const SizedBox(height: 4),
      Text(
        zone == null
            ? 'Browse local experiences around Cebu.'
            : 'Browse local experiences around ${trendsZoneTitle(zone)}.',
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 10),
      VibeCardGrid(
        vibes: nearby,
        onTap: (vibe) => _openVibe(vibe, zone),
      ),
      const SizedBox(height: 18),
      TrendsSectionHeader(
        title: "What's trending?",
        actionLabel: windowDays == 30 ? '7 days' : '30 days',
        onAction: () {
          ref.read(trendsWindowDaysProvider.notifier).state =
              windowDays == 30 ? 7 : 30;
        },
      ),
      const SizedBox(height: 8),
      TrendsPanel(child: _trendingBody(zone, trends, windowDays)),
      if (zone == null) ...[
        const SizedBox(height: 16),
        const TrendsSectionHeader(title: 'Nearby zones'),
        const SizedBox(height: 8),
        TrendsPanel(
          child: feedLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _hotZoneList(feedZones),
        ),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _openZoneOnMap(zone),
          icon: const Icon(Icons.map_outlined),
          label: Text(
            zone == null
                ? 'Explore Cebu on map'
                : 'Explore ${trendsZoneTitle(zone)} on map',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryAction,
            foregroundColor: AppColors.mapInk,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    ];
  }

  Widget _trendingBody(
    ZoneModel? zone,
    ZoneCategoryTrendsModel? trends,
    int windowDays,
  ) {
    if (zone == null) {
      return const Text(
        'Select a zone on Explore to compare approved tags with the previous period.',
        style: TextStyle(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      );
    }
    if (trends == null) {
      return const Text(
        'Trend comparisons load from approved tags in this zone. Pull to refresh if this stays empty.',
        style: TextStyle(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      );
    }
    if (!trends.enoughData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notEnoughTrendCopy(trends.minSample),
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A high all-time tag count is not the same as growth. This view only ranks categories with enough approved tags in the selected window.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      );
    }
    final growing = growingCategories(trends);
    final rows = growing.isNotEmpty ? growing : trends.categories.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          growing.isNotEmpty
              ? 'Approved tags in the last $windowDays days versus the previous $windowDays days.'
              : 'No category grew versus the previous $windowDays days. Totals below are volume, not growth.',
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        for (final row in rows)
          CategoryTrendRow(row: row, windowDays: windowDays),
      ],
    );
  }

  Widget _hotZoneList(List<ZoneModel> feedZones) {
    final zones = [...feedZones]
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    final top = zones.take(4).toList();
    if (top.isEmpty) {
      return const Text(
        'No live zones yet. Add a tag on Explore.',
        style: TextStyle(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Column(
      children: [
        for (final zone in top)
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                zoneDisplayTitle(zone),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(trendsZoneSubtitle(zone)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ref.read(selectedZoneProvider.notifier).state = zone;
                setState(() => _section = TrendsSection.forYou);
              },
            ),
          ),
      ],
    );
  }

  List<Widget> _vibes(ZoneModel? zone) {
    final preview = relevantVibes(zone, limit: kVibesTabPreview);
    final vibes = _showAllVibes ? kTrendVibes : preview;
    return [
      TrendsSectionHeader(
        title: 'Vibes',
        actionLabel: _showAllVibes ? 'Show less' : 'See all',
        onAction: () => setState(() => _showAllVibes = !_showAllVibes),
      ),
      const SizedBox(height: 4),
      Text(
        'Colorful experience cards for ${trendsZoneTitle(zone)}. '
        'These are suggestions, not verified category rankings.',
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 10),
      VibeCardGrid(
        vibes: vibes,
        onTap: (vibe) => _openVibe(vibe, zone),
      ),
    ];
  }

  List<Widget> _routes(ZoneModel? zone) {
    if (zone == null) {
      return const [
        TrendsPanel(
          child: Text(
            'Select a zone first. Routes are built from named places mapped around that area.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ];
    }
    final routeAsync = ref.watch(zoneWalkingRouteProvider(zone));
    return [
      const TrendsSectionHeader(title: 'Walking routes'),
      const SizedBox(height: 8),
      routeAsync.when(
        loading: () => const TrendsPanel(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => const TrendsPanel(
          child: Text(
            'Could not load mapped places for a route.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        data: (route) {
          if (route == null) {
            return const TrendsPanel(
              child: Text(
                'Not enough mapped places to suggest a walk here yet. Open Explore or a vibe card to browse individual spots.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            );
          }
          return WalkingRouteCard(
            route: route,
            onStopTap: (stop) => _openStop(zone, stop),
            onOpenMap: () => _openStop(zone, route.stops.first),
          );
        },
      ),
    ];
  }

  void _openVibe(TrendVibe vibe, ZoneModel? zone) {
    final center = zone == null
        ? const LatLng(10.3157, 123.8854)
        : LatLng(zone.centroidLat, zone.centroidLng);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlacesToGoSheet(
        vibeTitle: vibe.title,
        vibeKey: vibe.vibeKey,
        areaLabel: trendsZoneTitle(zone),
        lat: center.latitude,
        lng: center.longitude,
      ),
    );
  }

  void _openStop(ZoneModel zone, WalkingStop stop) {
    openAreaOnExplore(
      ref,
      context,
      focus: LatLng(stop.lat, stop.lng),
      zone: zone,
      title: stop.name,
    );
  }

  void _openZoneOnMap(ZoneModel? zone) {
    if (zone == null) {
      context.go('/explore');
      return;
    }
    openAreaOnExplore(
      ref,
      context,
      focus: LatLng(zone.centroidLat, zone.centroidLng),
      zone: zone,
      title: trendsZoneTitle(zone),
    );
  }

  ZoneModel? _resolveZone(
    ZoneModel? selected,
    List<ZoneModel> feedZones,
    String? id,
  ) {
    if (id != null && selected?.zoneId == id) return selected;
    if (id != null) {
      for (final zone in feedZones) {
        if (zone.zoneId == id) return zone;
      }
    }
    return selected;
  }
}
