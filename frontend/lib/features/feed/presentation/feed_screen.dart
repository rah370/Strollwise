import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../shared/models/report.dart';
import '../../../shared/providers/app_providers.dart';

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
  String _selectedFilter = 'Nearby';

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
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
                      selectedLabel: _selectedFilter,
                      labels: _filters,
                      onSelected: (label) {
                        setState(() => _selectedFilter = label);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: feed.when(
                        data: (reports) {
                          final filtered = _applyFilter(
                            reports,
                            _selectedFilter,
                          );
                          if (filtered.isEmpty) {
                            return const EmptyStateCard(
                              message: 'No reports for this tag filter yet.',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final report = filtered[index];
                              final likes = 12 + (index * 7) % 180;
                              final comments = 3 + (index % 8);
                              return _FeedItemCard(
                                report: report,
                                likes: likes,
                                comments: comments,
                                seed: index,
                              );
                            },
                          );
                        },
                        loading: LoadingSkeleton.new,
                        error: (error, _) =>
                            EmptyStateCard(message: error.toString()),
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

  List<ReportModel> _applyFilter(List<ReportModel> reports, String filter) {
    switch (filter.toLowerCase()) {
      case 'food':
        return reports.where((r) => _matches(r, 'food')).toList();
      case 'crowd':
        return reports.where((r) => _matches(r, 'crowd')).toList();
      case 'safety':
        return reports
            .where((r) => _matches(r, 'safety') || _matches(r, 'issue'))
            .toList();
      case 'trending':
        final sorted = [...reports];
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sorted;
      case 'following':
      case 'nearby':
      default:
        return reports;
    }
  }

  bool _matches(ReportModel report, String key) {
    final k = key.toLowerCase();
    return report.category.toLowerCase().contains(k) ||
        report.tags.any((tag) => tag.toLowerCase().contains(k)) ||
        (report.note?.toLowerCase().contains(k) ?? false);
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

class _FeedItemCard extends StatelessWidget {
  const _FeedItemCard({
    required this.report,
    required this.likes,
    required this.comments,
    required this.seed,
  });

  final ReportModel report;
  final int likes;
  final int comments;
  final int seed;

  Color _chipColor(String value) {
    switch (value.toLowerCase()) {
      case 'food':
        return const Color(0xFFF59E0B);
      case 'transport':
        return const Color(0xFF22C55E);
      case 'crowd':
        return const Color(0xFF3B82F6);
      case 'safety':
      case 'issue':
        return const Color(0xFFEF4444);
      case 'event':
        return const Color(0xFFA855F7);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = _chipColor(report.category);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomPaint(
                    painter: _MiniHexPainter(color: chip, seed: seed),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zone ${report.h3Index.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(report.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
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
                    color: chip.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: chip,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              report.note?.isNotEmpty == true
                  ? report.note!
                  : 'Community tag in this zone.',
              style: const TextStyle(
                height: 1.45,
                fontSize: 14,
                color: Color(0xFF334155),
              ),
            ),
          ),
          if (report.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in report.tags.take(4))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                _ActionStat(
                  icon: Icons.favorite_border_rounded,
                  value: '$likes',
                ),
                const SizedBox(width: 18),
                _ActionStat(
                  icon: Icons.mode_comment_outlined,
                  value: '$comments',
                ),
                const SizedBox(width: 18),
                const _ActionStat(icon: Icons.share_outlined, value: 'Share'),
                const Spacer(),
                const Icon(
                  Icons.bookmark_border_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ActionStat extends StatelessWidget {
  const _ActionStat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
