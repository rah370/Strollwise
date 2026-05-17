import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/zone_place_ui.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({this.zoneId, super.key});

  final String? zoneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedZone = ref.watch(selectedZoneProvider);
    final feedZones =
        ref.watch(zoneFeedProvider).valueOrNull ?? const <ZoneModel>[];
    final zone = _resolveZone(selectedZone, feedZones, zoneId);
    final intelligence = zone == null ? null : _ZoneIntelligence.fromZone(zone);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(zoneFeedProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _Hero(zone: zone, intelligence: intelligence),
              const SizedBox(height: 14),
              if (intelligence != null) ...[
                _ZoneSignalCard(zone: zone!, intelligence: intelligence),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Trending Near ${_compactZoneLabel(zone.displayName)}',
                  subtitle:
                      'Tap a trend to open matching nearby areas in Explore. ${intelligence.zoneType} · ${intelligence.travelerMix} · ${intelligence.peakTime} peak.',
                  child: _TrendWrap(
                    items: intelligence.trends,
                    onTap: (trend) => _openExploreAt(context, ref, trend),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Suggested Zone Experience',
                  subtitle: intelligence.routeName,
                  child: _RouteTimeline(
                    stops: intelligence.routeStops,
                    activities: intelligence.routeActivities,
                    onStopTap: (stop) => _openExploreAt(context, ref, stop),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _SectionCard(
                title: 'Cebu Behavior Map',
                subtitle:
                    'Areas are grouped by zone behavior, not just by place category.',
                child: _AreaIntelligenceTable(
                  onAreaTap: (area) => _openExploreAt(context, ref, area),
                ),
              ),
              const SizedBox(height: 12),
              const _FoodBehaviorCard(),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Trend Categories',
                subtitle:
                    'These are the behavior lenses StrollWise should rank per zone.',
                child: _TrendCatalog(
                  onTrendTap: (trend) => _openExploreAt(context, ref, trend),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Example Itineraries',
                subtitle:
                    'Routes combine local movement patterns with activities.',
                child: _ItineraryList(
                  onPlaceTap: (place) => _openExploreAt(context, ref, place),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openExploreAt(BuildContext context, WidgetRef ref, String label) {
    final target = _locationForLabel(label);
    ref.read(selectedZoneProvider.notifier).state = null;
    ref.read(currentUserLocationProvider.notifier).state = target;
    ref.read(exploreFocusLocationProvider.notifier).state = target;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Opening Explore near ${_cleanPlaceLabel(label)}'),
        ),
      );
    context.go('/explore');
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

class _Hero extends StatelessWidget {
  const _Hero({required this.zone, required this.intelligence});

  final ZoneModel? zone;
  final _ZoneIntelligence? intelligence;

  @override
  Widget build(BuildContext context) {
    final intel = intelligence;
    final title = zone?.displayName ?? 'Zone Intelligence';
    final subtitle = intel == null
        ? 'Track what people are doing in Cebu zones: food behavior, traveler mix, peak time, and activity combinations.'
        : '${intel.zoneType} · ${intel.travelerMix} · ${intel.peakTime} peak';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.mapInk,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                color: Colors.white,
                size: 30,
              ),
              const Spacer(),
              if (zone != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${zone!.confidenceScore.round()}% confidence',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFBAE6FD),
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.mutedText,
              height: 1.35,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ZoneSignalCard extends StatelessWidget {
  const _ZoneSignalCard({required this.zone, required this.intelligence});

  final ZoneModel zone;
  final _ZoneIntelligence intelligence;

  @override
  Widget build(BuildContext context) {
    final crowdPercent = (zone.crowdLevel * 100).clamp(0, 100).round();
    return _SectionCard(
      title: 'Selected Zone Signal',
      subtitle: 'Why StrollWise is recommending this area behavior right now.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Pill(icon: Icons.place_outlined, label: intelligence.zoneType),
          _Pill(
            icon: Icons.people_alt_outlined,
            label: intelligence.travelerMix,
          ),
          _Pill(
            icon: Icons.schedule_outlined,
            label: '${intelligence.peakTime} peak',
          ),
          _Pill(
            icon: Icons.bubble_chart_outlined,
            label: '$crowdPercent% activity',
          ),
          _Pill(
            icon: Icons.verified_outlined,
            label: '${zone.confidenceScore.round()}% confidence',
          ),
          _Pill(icon: Icons.flag_outlined, label: '${zone.reportCount} tags'),
        ],
      ),
    );
  }
}

class _TrendWrap extends StatelessWidget {
  const _TrendWrap({required this.items, this.onTap});

  final List<String> items;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          _Pill(
            icon: _iconForTrend(item),
            label: item,
            onTap: onTap == null ? null : () => onTap!(item),
          ),
      ],
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({
    required this.stops,
    required this.activities,
    required this.onStopTap,
  });

  final List<String> stops;
  final List<String> activities;
  final ValueChanged<String> onStopTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stops.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == stops.length - 1 ? 0 : 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onStopTap(stops[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.22),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: AppColors.mapInk,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stops[i],
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.map_outlined,
                      size: 16,
                      color: AppColors.primaryAction,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _TrendWrap(items: activities),
      ],
    );
  }
}

class _AreaIntelligenceTable extends StatelessWidget {
  const _AreaIntelligenceTable({required this.onAreaTap});

  final ValueChanged<String> onAreaTap;

  static const rows = [
    _AreaRow(
      'IT Park',
      'Commercial / Food',
      'Sugbo Mercado, cafes, coworking',
      'Mixed',
      'food, work, nightlife, study',
      'Night',
    ),
    _AreaRow(
      'Colon',
      'Historical / Commercial',
      'Carbon, Basilica, street food',
      'Local-heavy',
      'heritage, shopping, food',
      'Day',
    ),
    _AreaRow(
      'Mactan Resort Area',
      'Tourist / Hotel',
      'resorts, beach clubs',
      'Tourist-heavy',
      'beach, diving, nightlife',
      'Afternoon',
    ),
    _AreaRow(
      'Busay',
      'Nature / Tourist',
      'Tops, Temple of Leah',
      'Tourist-heavy',
      'sightseeing, coffee, mountain drive',
      'Sunset',
    ),
    _AreaRow(
      'Fuente',
      'Transport / Food',
      'Robinsons, Larsian',
      'Local-heavy',
      'commute, food, shopping',
      'Evening',
    ),
    _AreaRow(
      'Cebu Taoist Temple',
      'Cultural / Viewpoint',
      'Beverly Hills, city views',
      'Tourist-heavy',
      'sightseeing, photo stops, quiet walk',
      'Day',
    ),
    _AreaRow(
      'Sirao Flower Garden',
      'Nature / Photo Spot',
      'flower gardens, mountain road',
      'Tourist-heavy',
      'photo stop, weekend drive, sightseeing',
      'Afternoon',
    ),
    _AreaRow(
      'South Bus Terminal',
      'Transit / Budget',
      'bus terminal, cheap eats',
      'Local-heavy',
      'commute, budget travel, local food',
      'Morning',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows)
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onAreaTap(row.area),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.area,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        row.peakTime,
                        style: const TextStyle(
                          color: AppColors.primaryAction,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.map_outlined,
                        size: 16,
                        color: AppColors.primaryAction,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${row.zoneType} · ${row.travelerMix}',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    row.hotspots,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    row.activities,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FoodBehaviorCard extends StatelessWidget {
  const _FoodBehaviorCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Food Behavior Split',
      subtitle:
          'Local and tourist food zones behave differently, so they should rank differently.',
      child: Column(
        children: const [
          _BehaviorColumn(
            title: 'Local Food Zones',
            description: 'Cheaper, practical, authentic, street-oriented.',
            items: [
              'Larsian',
              'Carbon night food',
              'Pungko-pungko areas',
              'Carinderias',
              'Barbecue streets',
              'Wet market food',
            ],
          ),
          SizedBox(height: 12),
          _BehaviorColumn(
            title: 'International / Tourist Food Zones',
            description:
                'Visible, safe-looking, aesthetic, accessible, highly rated online.',
            items: [
              'Rooftop restaurants',
              'Cafes',
              'Aesthetic restaurants',
              'Resorts',
              'Buffet areas',
              'Seafood restaurants',
            ],
          ),
        ],
      ),
    );
  }
}

class _BehaviorColumn extends StatelessWidget {
  const _BehaviorColumn({
    required this.title,
    required this.description,
    required this.items,
  });

  final String title;
  final String description;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.mutedText,
              height: 1.35,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _TrendWrap(items: items),
        ],
      ),
    );
  }
}

class _TrendCatalog extends StatelessWidget {
  const _TrendCatalog({required this.onTrendTap});

  final ValueChanged<String> onTrendTap;

  static const items = [
    'Food Crawl Trends',
    'Cafe and Study Trends',
    'Nightlife Trends',
    'Heritage Walk Trends',
    'Nature Escape Trends',
    'Student Activity Trends',
    'Weekend Local Trends',
    'Budget Traveler Trends',
    'Digital Nomad Trends',
    'Commute and Transit Trends',
    'Shopping Trends',
    'Wellness and Relaxation Trends',
    'Family Activity Trends',
    'Adventure Trends',
    'Hidden Local Spots',
  ];

  @override
  Widget build(BuildContext context) =>
      _TrendWrap(items: items, onTap: onTrendTap);
}

class _ItineraryList extends StatelessWidget {
  const _ItineraryList({required this.onPlaceTap});

  final ValueChanged<String> onPlaceTap;

  static const items = [
    _Itinerary(
      'Historical Cebu Trail',
      ['Basilica', 'Magellan’s Cross', 'Fort San Pedro', 'Colon food stop'],
      ['heritage walk', 'museum', 'local food'],
    ),
    _Itinerary(
      'Nightlife + Food Route',
      ['IT Park', 'Sugbo Mercado', 'Streetscape', 'rooftop bars'],
      ['food crawl', 'nightlife', 'social hangout'],
    ),
    _Itinerary(
      'Local Student Route',
      ['USC Talamban', 'cafes', 'study hubs', 'cheap food areas'],
      ['study', 'budget meals', 'coworking'],
    ),
    _Itinerary(
      'Nature + Relaxation Route',
      ['Busay', 'Temple of Leah', 'Tops', 'mountain cafes'],
      ['sightseeing', 'coffee', 'sunset drive'],
    ),
    _Itinerary(
      'Weekend Family Route',
      ['Ocean Park', 'IL Corso', 'SRP'],
      ['family bonding', 'dining', 'walking'],
    ),
    _Itinerary(
      'Budget Backpacker Route',
      ['South Bus Terminal', 'Colon', 'cheap inns', 'local eateries'],
      ['budget travel', 'local exploration'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onPlaceTap(item.stops.first),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final stop in item.stops)
                        _Pill(
                          icon: Icons.place_outlined,
                          label: stop,
                          onTap: () => onPlaceTap(stop),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _TrendWrap(items: item.activities),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;
    final chip = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.mapInk),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 5),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: AppColors.primaryAction,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: chip,
    );
  }
}

String _compactZoneLabel(String displayName) {
  final normalized = displayName.trim();
  final lower = normalized.toLowerCase();

  if (lower.contains('usc main')) {
    return 'USC Main';
  }
  if (lower.contains('usc talamban')) {
    return 'USC Talamban';
  }
  if (lower.contains('it park')) {
    return 'IT Park';
  }
  if (lower.contains('ayala')) {
    return 'Ayala';
  }
  if (lower.contains('colon')) {
    return 'Colon';
  }
  if (lower.contains('carbon')) {
    return 'Carbon Market';
  }
  if (lower.contains('busay')) {
    return 'Busay';
  }
  if (lower.contains('mactan')) {
    return 'Mactan';
  }
  if (lower.contains('fuente')) {
    return 'Fuente';
  }
  if (lower.contains('pier')) {
    return 'Pier Area';
  }
  if (lower.contains('sirao')) {
    return 'Sirao';
  }

  return normalized
      .replaceAll(RegExp(r'\bzone\b', caseSensitive: false), '')
      .replaceAll(
        RegExp(
          r'\b(student|activity|commercial|local|food|shopping|transit|safety|nature|sunset|resort|beach|neighborhood|market)\b',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+\+\s+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

class _ZoneIntelligence {
  const _ZoneIntelligence({
    required this.zoneType,
    required this.travelerMix,
    required this.peakTime,
    required this.trends,
    required this.routeName,
    required this.routeStops,
    required this.routeActivities,
  });

  final String zoneType;
  final String travelerMix;
  final String peakTime;
  final List<String> trends;
  final String routeName;
  final List<String> routeStops;
  final List<String> routeActivities;

  factory _ZoneIntelligence.fromZone(ZoneModel zone) {
    final name = zone.displayName.toLowerCase();
    final function = zone.zoneType;
    final travelerMix = travelerMixTrendLabel(zone.travelerMix);

    if (name.contains('colon') || name.contains('basilica')) {
      return const _ZoneIntelligence(
        zoneType: 'Historical / Commercial',
        travelerMix: 'Local-heavy',
        peakTime: 'Day',
        trends: [
          'Heritage Walk Trends',
          'Shopping Trends',
          'Local Food Zones',
          'Budget Traveler Trends',
        ],
        routeName: 'Historical Cebu Trail',
        routeStops: [
          'Basilica',
          'Magellan’s Cross',
          'Fort San Pedro',
          'Colon food stop',
        ],
        routeActivities: ['heritage walk', 'museum', 'local food'],
      );
    }
    if (name.contains('busay') ||
        name.contains('tops') ||
        name.contains('leah')) {
      return const _ZoneIntelligence(
        zoneType: 'Nature / Tourist',
        travelerMix: 'Tourist-heavy',
        peakTime: 'Sunset',
        trends: [
          'Nature Escape Trends',
          'Cafe and Study Trends',
          'Wellness and Relaxation Trends',
          'Hidden Local Spots',
        ],
        routeName: 'Nature + Relaxation Route',
        routeStops: ['Busay', 'Temple of Leah', 'Tops', 'mountain cafes'],
        routeActivities: ['sightseeing', 'coffee', 'sunset drive'],
      );
    }
    if (name.contains('mactan') || name.contains('resort')) {
      return const _ZoneIntelligence(
        zoneType: 'Tourist / Hotel',
        travelerMix: 'Tourist-heavy',
        peakTime: 'Afternoon',
        trends: [
          'Wellness and Relaxation Trends',
          'Adventure Trends',
          'Nightlife Trends',
          'International / Tourist Food Zones',
        ],
        routeName: 'Mactan Resort Day',
        routeStops: [
          'resorts',
          'beach clubs',
          'seafood restaurants',
          'nightlife',
        ],
        routeActivities: ['beach', 'diving', 'nightlife'],
      );
    }
    if (name.contains('fuente') || function == 'transport_zone') {
      return const _ZoneIntelligence(
        zoneType: 'Transport / Food',
        travelerMix: 'Local-heavy',
        peakTime: 'Evening',
        trends: [
          'Commute and Transit Trends',
          'Food Crawl Trends',
          'Shopping Trends',
          'Weekend Local Trends',
        ],
        routeName: 'Fuente Food + Transit Loop',
        routeStops: [
          'Robinsons',
          'Larsian',
          'commute corridors',
          'shopping streets',
        ],
        routeActivities: ['commute', 'food', 'shopping'],
      );
    }
    if (function == 'student_area' || name.contains('usc')) {
      return const _ZoneIntelligence(
        zoneType: 'Student / Budget',
        travelerMix: 'Local-heavy',
        peakTime: 'Afternoon',
        trends: [
          'Student Activity Trends',
          'Cafe and Study Trends',
          'Budget Traveler Trends',
          'Hidden Local Spots',
        ],
        routeName: 'Local Student Route',
        routeStops: ['USC Talamban', 'cafes', 'study hubs', 'cheap food areas'],
        routeActivities: ['study', 'budget meals', 'coworking'],
      );
    }
    if (function == 'food_hotspot') {
      return _ZoneIntelligence(
        zoneType: 'Food / Social',
        travelerMix: travelerMix,
        peakTime: zone.peakTimeLabel ?? 'Evening',
        trends: const [
          'Food Crawl Trends',
          'Weekend Local Trends',
          'Hidden Local Spots',
          'Local Food Zones',
        ],
        routeName: 'Food Crawl Route',
        routeStops: const [
          'main food cluster',
          'side-street stalls',
          'cafes',
          'late-night stop',
        ],
        routeActivities: const [
          'food crawl',
          'local exploration',
          'social hangout',
        ],
      );
    }
    return _ZoneIntelligence(
      zoneType: _titleize(function.replaceAll('_', ' / ')),
      travelerMix: travelerMix,
      peakTime: zone.peakTimeLabel ?? 'Variable',
      trends: const [
        'Weekend Local Trends',
        'Shopping Trends',
        'Cafe and Study Trends',
        'Hidden Local Spots',
      ],
      routeName: 'Zone Experience Route',
      routeStops: const [
        'area center',
        'nearby activity cluster',
        'food stop',
        'walkable edge',
      ],
      routeActivities: const ['local exploration', 'walking', 'dining'],
    );
  }
}

class _AreaRow {
  const _AreaRow(
    this.area,
    this.zoneType,
    this.hotspots,
    this.travelerMix,
    this.activities,
    this.peakTime,
  );

  final String area;
  final String zoneType;
  final String hotspots;
  final String travelerMix;
  final String activities;
  final String peakTime;
}

class _Itinerary {
  const _Itinerary(this.title, this.stops, this.activities);

  final String title;
  final List<String> stops;
  final List<String> activities;
}

LatLng _locationForLabel(String label) {
  final key = label.toLowerCase();
  if (key.contains('it park') ||
      key.contains('sugbo') ||
      key.contains('nightlife') ||
      key.contains('digital nomad')) {
    return const LatLng(10.3306, 123.9056);
  }
  if (key.contains('colon') ||
      key.contains('carbon') ||
      key.contains('heritage') ||
      key.contains('basilica') ||
      key.contains('magellan')) {
    return const LatLng(10.2968, 123.9015);
  }
  if (key.contains('fort san pedro') || key.contains('museum')) {
    return const LatLng(10.2927, 123.9058);
  }
  if (key.contains('busay') ||
      key.contains('tops') ||
      key.contains('temple of leah') ||
      key.contains('nature') ||
      key.contains('sunset') ||
      key.contains('mountain')) {
    return const LatLng(10.3700, 123.8780);
  }
  if (key.contains('sirao') || key.contains('flower')) {
    return const LatLng(10.3940, 123.8680);
  }
  if (key.contains('taoist')) {
    return const LatLng(10.3410, 123.8885);
  }
  if (key.contains('mactan') ||
      key.contains('resort') ||
      key.contains('beach') ||
      key.contains('diving')) {
    return const LatLng(10.2983, 124.0155);
  }
  if (key.contains('fuente') ||
      key.contains('larsian') ||
      key.contains('robinsons')) {
    return const LatLng(10.3105, 123.8921);
  }
  if (key.contains('usc') ||
      key.contains('student') ||
      key.contains('talamban') ||
      key.contains('study')) {
    return const LatLng(10.3545, 123.9139);
  }
  if (key.contains('ocean park') ||
      key.contains('il corso') ||
      key.contains('srp') ||
      key.contains('family')) {
    return const LatLng(10.2665, 123.8812);
  }
  if (key.contains('south bus') ||
      key.contains('budget') ||
      key.contains('backpacker') ||
      key.contains('transit') ||
      key.contains('commute')) {
    return const LatLng(10.3001, 123.8931);
  }
  if (key.contains('shopping')) {
    return const LatLng(10.3181, 123.9056);
  }
  if (key.contains('wellness') || key.contains('relaxation')) {
    return const LatLng(10.2983, 124.0155);
  }
  return const LatLng(10.3157, 123.8854);
}

String _cleanPlaceLabel(String label) {
  return label.replaceAll('Trends', '').replaceAll('Route', '').trim();
}

IconData _iconForTrend(String trend) {
  final t = trend.toLowerCase();
  if (t.contains('food') || t.contains('dining') || t.contains('carinderia')) {
    return Icons.restaurant_outlined;
  }
  if (t.contains('cafe') || t.contains('study') || t.contains('nomad')) {
    return Icons.local_cafe_outlined;
  }
  if (t.contains('night')) {
    return Icons.nightlife_outlined;
  }
  if (t.contains('heritage') || t.contains('historical')) {
    return Icons.museum_outlined;
  }
  if (t.contains('nature') || t.contains('adventure') || t.contains('beach')) {
    return Icons.landscape_outlined;
  }
  if (t.contains('student')) {
    return Icons.school_outlined;
  }
  if (t.contains('transit') || t.contains('commute')) {
    return Icons.directions_bus_outlined;
  }
  if (t.contains('shopping') || t.contains('market')) {
    return Icons.shopping_bag_outlined;
  }
  if (t.contains('family')) {
    return Icons.family_restroom_outlined;
  }
  if (t.contains('wellness') || t.contains('relaxation')) {
    return Icons.spa_outlined;
  }
  return Icons.explore_outlined;
}

String _titleize(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
