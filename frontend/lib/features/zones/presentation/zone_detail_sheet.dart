import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/app_providers.dart';

class ZoneDetailSheet extends ConsumerWidget {
  const ZoneDetailSheet({super.key});

  static const _tealBg = AppColors.mapInk;
  static const _chipBg = Color(0xFFE0F2FE);
  static const _chipText = AppColors.lagoon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(selectedZoneProvider);
    if (zone == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No zone selected')),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: _tealBg,
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(child: _ZoneHero(zone: zone)),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                    child: _ZoneBody(zone: zone),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZoneHero extends StatelessWidget {
  const _ZoneHero({required this.zone});

  final ZoneModel zone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeroIconButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                Text(
                  zone.zoneType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
                const _HeroIconButton(icon: Icons.bookmark_border_rounded),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: _HexCluster(
                travelerColor: _colorFromHex(zone.fillColor),
                borderColor: _colorFromHex(zone.borderColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  final normalized = hex.replaceAll('#', '');
  if (normalized.length != 6) return const Color(0xFFFED64A);
  return Color(int.parse('FF$normalized', radix: 16));
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _HexCluster extends StatelessWidget {
  const _HexCluster({required this.travelerColor, required this.borderColor});

  final Color travelerColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 360.0);
        return Center(
          child: SizedBox(
            width: size,
            height: 190,
            child: CustomPaint(
              painter: _HexClusterPainter(
                selectedFill: travelerColor.withValues(alpha: 0.82),
                selectedBorder: borderColor,
                neighborFill: travelerColor.withValues(alpha: 0.16),
                neighborBorder: borderColor.withValues(alpha: 0.32),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HexClusterPainter extends CustomPainter {
  _HexClusterPainter({
    required this.selectedFill,
    required this.selectedBorder,
    required this.neighborFill,
    required this.neighborBorder,
  });

  final Color selectedFill;
  final Color selectedBorder;
  final Color neighborFill;
  final Color neighborBorder;

  void _drawHex(
    Canvas canvas,
    Offset center,
    double radius,
    Color fill,
    Color border, {
    double strokeWidth = 2.2,
  }) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 5.6;
    final hexWidth = radius * math.sqrt(3);
    final hexHeight = radius * 1.5;

    final selectedCoord = (0, 0);
    final neighborCoords = <(int, int)>{
      (-1, 0),
      (1, 0),
      (0, -1),
      (0, 1),
      (-1, 1),
      (1, -1),
      (-2, 0),
      (2, 0),
      (-1, -1),
      (1, 1),
      (-2, 1),
      (2, -1),
    };

    Offset axialToPixel(int q, int r) {
      final dx = hexWidth * (q + r / 2);
      final dy = hexHeight * r;
      return Offset(center.dx + dx, center.dy + dy);
    }

    for (final (q, r) in neighborCoords) {
      _drawHex(
        canvas,
        axialToPixel(q, r),
        radius,
        neighborFill,
        neighborBorder,
        strokeWidth: 1.6,
      );
    }
    _drawHex(
      canvas,
      axialToPixel(selectedCoord.$1, selectedCoord.$2),
      radius * 1.02,
      selectedFill,
      selectedBorder,
      strokeWidth: 3.2,
    );
  }

  @override
  bool shouldRepaint(covariant _HexClusterPainter oldDelegate) =>
      oldDelegate.selectedFill != selectedFill ||
      oldDelegate.selectedBorder != selectedBorder;
}

class _ZoneBody extends ConsumerWidget {
  const _ZoneBody({required this.zone});

  final ZoneModel zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(currentZoneOverviewProvider).valueOrNull;
    final alternatives = overview?.alternativeZones ?? const <ZoneModel>[];
    final lat = zone.boundary.isNotEmpty
        ? zone.boundary.map((p) => p[1]).reduce((a, b) => a + b) /
              zone.boundary.length
        : 0.0;
    final lng = zone.boundary.isNotEmpty
        ? zone.boundary.map((p) => p[0]).reduce((a, b) => a + b) /
              zone.boundary.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.zoneType,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _colorFromHex(zone.borderColor).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${zone.reportCount}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _InfoChip(
              icon: Icons.calendar_month_outlined,
              label: _crowdLabel(zone),
            ),
            const SizedBox(width: 10),
            _InfoChip(
              icon: Icons.folder_outlined,
              label: '${zone.popularityScore.toStringAsFixed(0)}%',
            ),
            const SizedBox(width: 10),
            _InfoIconChip(icon: Icons.notifications_none_rounded),
          ],
        ),
        const SizedBox(height: 20),
        _SectionHeading(title: 'Traveler mix'),
        const SizedBox(height: 8),
        _TravelerMixBar(zone: zone),
        const SizedBox(height: 20),
        _SectionHeading(title: 'About this Zone'),
        const SizedBox(height: 8),
        Text(
          'This ${zone.zoneType.toLowerCase()} zone shows ${zone.travelerType.toLowerCase()} activity patterns. '
          'Confidence is ${zone.confidenceScore.toStringAsFixed(0)}% based on recent community tags.',
          style: const TextStyle(
            height: 1.4,
            color: Color(0xFF334155),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeading(title: 'Top Activities'),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _IconLabel(icon: Icons.landscape, label: 'Sightseeing'),
            _IconLabel(icon: Icons.shopping_bag_outlined, label: 'Shopping'),
            _IconLabel(icon: Icons.restaurant_outlined, label: 'Dining'),
            _IconLabel(icon: Icons.nightlife_outlined, label: 'Nightlife'),
          ],
        ),
        const SizedBox(height: 20),
        if (alternatives.isNotEmpty) ...[
          _SectionHeading(title: 'Nearby Alternatives'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: alternatives
                .map(
                  (candidate) => _IconLabel(
                    icon: Icons.alt_route_rounded,
                    label: candidate.displayName,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        _SectionHeading(title: 'Transport'),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _IconLabel(icon: Icons.directions_bus_outlined, label: 'Bus'),
            _IconLabel(icon: Icons.local_taxi_outlined, label: 'Taxi'),
            _IconLabel(icon: Icons.local_parking_outlined, label: 'Parking'),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ZoneDetailSheet._tealBg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.near_me_outlined, size: 20),
                  label: const Text('Explore Zone'),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF0F172A),
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _crowdLabel(ZoneModel zone) {
    if (zone.reportCount >= 40) return 'High crowd';
    if (zone.reportCount >= 20) return 'Moderate';
    return 'Quiet';
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ZoneDetailSheet._chipBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ZoneDetailSheet._chipText),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: ZoneDetailSheet._chipText,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoIconChip extends StatelessWidget {
  const _InfoIconChip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: ZoneDetailSheet._chipBg,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.notifications_none_rounded,
        size: 18,
        color: ZoneDetailSheet._chipText,
      ),
    );
  }
}

class _TravelerMixBar extends StatelessWidget {
  const _TravelerMixBar({required this.zone});

  final ZoneModel zone;

  @override
  Widget build(BuildContext context) {
    final locals = switch (zone.travelerType.toLowerCase()) {
      'local' => 0.78,
      'international' => 0.18,
      _ => 0.52,
    };
    final intl = 1 - locals;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (locals * 100).round(),
                  child: Container(color: const Color(0xFF22C55E)),
                ),
                Expanded(
                  flex: (intl * 100).round(),
                  child: Container(color: const Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Locals ${(locals * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'International ${(intl * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F172A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
