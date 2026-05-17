import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/zone_place_ui.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  static const _tealBg = Color(0xFF00628A);

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  static const _filters = [
    'Following',
    'Nearby',
    'Trending',
    'Food',
    'Crowd',
    'Safety',
  ];

  static const _backgroundRefreshInterval = Duration(seconds: 50);

  Timer? _backgroundRefresh;

  @override
  void initState() {
    super.initState();
    _backgroundRefresh = Timer.periodic(_backgroundRefreshInterval, (_) {
      if (!mounted) return;
      ref.invalidate(zoneFeedProvider);
    });
  }

  @override
  void dispose() {
    _backgroundRefresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(zoneFeedProvider);
    final selectedChip = ref.watch(zoneFeedChipProvider);
    final zoneDataNotice = ref.watch(zoneDataNoticeProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > 720
              ? 680.0
              : constraints.maxWidth;
          return SafeArea(
            bottom: false,
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    const _FeedHeader(),
                    const SizedBox(height: 4),
                    _FeedFilterRow(
                      selectedLabel: selectedChip,
                      labels: _filters,
                      onSelected: (label) {
                        ref.read(zoneFeedChipProvider.notifier).state = label;
                      },
                    ),
                    if (zoneDataNotice != null) ...[
                      const SizedBox(height: 8),
                      _FeedCacheNotice(message: zoneDataNotice),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: feed.when(
                        data: (zones) {
                          return RefreshIndicator(
                            onRefresh: () =>
                                ref.refresh(zoneFeedProvider.future),
                            child: zones.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.only(top: 48),
                                    children: const [
                                      EmptyStateCard(
                                        message:
                                            'No zones match this filter yet. Pull to refresh.',
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      24,
                                    ),
                                    itemCount: zones.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      return _ZoneFeedCard(
                                        zone: zones[index],
                                        seed: index,
                                      );
                                    },
                                  ),
                          );
                        },
                        loading: LoadingSkeleton.new,
                        error: (error, _) => RefreshIndicator(
                          onRefresh: () => ref.refresh(zoneFeedProvider.future),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 48),
                            children: [
                              EmptyStateCard(message: error.toString()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const Text(
            'Zone Feed',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          _IconCircle(icon: Icons.search_rounded, onTap: () {}),
          const SizedBox(width: 8),
          _IconCircle(icon: Icons.tune_rounded, onTap: () {}),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}

class _FeedCacheNotice extends StatelessWidget {
  const _FeedCacheNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
      height: 36,
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
            color: selected ? FeedScreen._tealBg : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? FeedScreen._tealBg : const Color(0xFFE2E8F0),
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

class _ZoneFeedCard extends StatelessWidget {
  const _ZoneFeedCard({required this.zone, required this.seed});

  final ZoneModel zone;
  final int seed;

  static Color _parseHex(String hex) {
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) {
      h = 'FF$h';
    }
    return Color(int.parse(h, radix: 16));
  }

  String _cardTitle() => zoneDisplayTitle(zone);

  String _cardSubtitle() => zoneMapSubtitle(zone);

  @override
  Widget build(BuildContext context) {
    final accent = _parseHex(zone.borderColor);
    final crowdPct = (zone.crowdLevel * 100).clamp(0, 100).round();
    final summary = (zone.summary?.trim().isNotEmpty == true)
        ? zone.summary!.trim()
        : 'Ranked from community signals in this H3 area.';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomPaint(
                    painter: _MiniHexPainter(color: accent, seed: seed),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cardTitle(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _cardSubtitle(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '★ ${zone.confidenceScore.round()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                height: 1.45,
                fontSize: 14,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.bubble_chart_outlined,
                  label: zone.liveStatus.replaceAll('_', ' '),
                ),
                _MetaChip(
                  icon: Icons.people_outline_rounded,
                  label: '$crowdPct% activity',
                ),
                _MetaChip(
                  icon: Icons.flag_outlined,
                  label: '${zone.reportCount} reports',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHexPainter extends CustomPainter {
  _MiniHexPainter({required this.color, required this.seed});

  final Color color;
  final int seed;

  void _hex(Canvas canvas, Offset center, double r, Paint fill, Paint stroke) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 4.2;
    final hexWidth = r * math.sqrt(3);
    final hexHeight = r * 1.5;

    final lightFill = Paint()..color = color.withValues(alpha: 0.18);
    final lightStroke = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final mainFill = Paint()..color = color.withValues(alpha: 0.9);
    final mainStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final neighbors = [
      Offset(-hexWidth, 0),
      Offset(hexWidth, 0),
      Offset(-hexWidth / 2, -hexHeight),
      Offset(hexWidth / 2, -hexHeight),
      Offset(-hexWidth / 2, hexHeight),
      Offset(hexWidth / 2, hexHeight),
    ];
    for (final offset in neighbors) {
      _hex(canvas, center + offset, r * 0.58, lightFill, lightStroke);
    }
    _hex(canvas, center, r * 0.7, mainFill, mainStroke);
  }

  @override
  bool shouldRepaint(covariant _MiniHexPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}
