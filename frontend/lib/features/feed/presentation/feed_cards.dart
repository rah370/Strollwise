import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/traveler_gradient.dart';
import '../../../shared/zone_place_ui.dart';
import 'feed_stream.dart';
import 'feed_zone_copy.dart';

const feedMint = Color(0xFFD7EFE8);
const feedInk = Color(0xFF0F172A);
const feedMuted = Color(0xFF64748B);

class FeedMicroPostCard extends StatelessWidget {
  const FeedMicroPostCard({
    required this.post,
    required this.liked,
    required this.onOpenMap,
    required this.onAddTag,
    required this.onToggleLike,
    super.key,
  });

  final FeedMicroPost post;
  final bool liked;
  final VoidCallback onOpenMap;
  final VoidCallback onAddTag;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final report = post.report;
    final zone = post.zone;
    final handle = feedAuthorHandle(report);
    final mix = zone == null ? 0.5 : TravelerGradient.localRatioForZone(zone);
    final localPct = (mix * 100).round().clamp(0, 100);
    final visitorPct = 100 - localPct;
    final hasThread = post.replies.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  _AuthorAvatar(handle: handle),
                  if (hasThread)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$handle · ${feedTimeAgo(report.createdAt)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: feedInk,
                          ),
                        ),
                      ),
                      _MoreButton(onOpenMap: onOpenMap, onAddTag: onAddTag),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ZonePill(
                    label: feedZonePillLabel(zone),
                    color: zone == null
                        ? AppColors.primaryAction
                        : Color(
                            int.parse(
                              'FF${zone.borderColor.replaceFirst('#', '')}',
                              radix: 16,
                            ),
                          ),
                    onTap: onOpenMap,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feedPostBody(report),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (report.imageUrl != null &&
                      report.imageUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        report.imageUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _MixBadge(localPct: localPct, visitorPct: visitorPct),
                  const SizedBox(height: 4),
                  _ActionRow(
                    liked: liked,
                    onLike: onToggleLike,
                    onComment: onAddTag,
                    onShare: onOpenMap,
                    onPin: onOpenMap,
                  ),
                  if (hasThread) ...[
                    const SizedBox(height: 8),
                    for (final reply in post.replies)
                      _NestedReply(reply: reply),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedPulseCard extends StatelessWidget {
  const FeedPulseCard({
    required this.pulse,
    required this.onOpenMap,
    required this.onAddTag,
    super.key,
  });

  final FeedPulse pulse;
  final VoidCallback onOpenMap;
  final VoidCallback onAddTag;

  @override
  Widget build(BuildContext context) {
    final zone = pulse.zone;
    final accent = Color(
      int.parse(
        'FF${zone.borderColor.replaceFirst('#', '')}',
        radix: 16,
      ),
    );
    final mix = TravelerGradient.localRatioForZone(zone);
    final localPct = (mix * 100).round().clamp(0, 100);
    final visitorPct = 100 - localPct;
    final hasThread = pulse.replies.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  _AuthorAvatar(
                    handle: zoneDisplayTitle(zone),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CustomPaint(
                        painter: FeedHexClusterPainter(color: accent),
                      ),
                    ),
                  ),
                  if (hasThread)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Zone Pulse',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: feedMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CustomPaint(
                            painter: FeedHexClusterPainter(color: accent),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                zoneDisplayTitle(zone),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: feedInk,
                                ),
                              ),
                              Text(
                                '${feedCrowdLabel(zone)} · ${zone.reportCount} tags',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: feedMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PulseMixBar(
                      localPct: localPct,
                      visitorPct: visitorPct,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onOpenMap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: feedInk,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View on map',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (hasThread) ...[
                      const SizedBox(height: 8),
                      for (final reply in pulse.replies)
                        _NestedReply(reply: reply),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onAddTag,
                        child: const Text(
                          'Ask this area',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedComposerBar extends StatelessWidget {
  const FeedComposerBar({required this.onAddTag, super.key});

  final ValueChanged<String> onAddTag;

  static const moods = ['Calm', 'Busy', 'Great Coffee'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onAddTag(''),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Drop a 5-second tag',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: feedInk,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final mood in moods)
                      ActionChip(
                        label: Text(mood),
                        onPressed: () => onAddTag(mood),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFFF0FDFA),
                        side: const BorderSide(color: Color(0xFFB8E6D5)),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.handle, this.child});

  final String handle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final hue = (handle.hashCode.abs() % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.38, 0.62).toColor();
    final letter = handle.replaceAll('@', '');
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.22),
      child: child ??
          Text(
            letter.isEmpty ? 'S' : letter[0].toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F766E),
            ),
          ),
    );
  }
}

class _ZonePill extends StatelessWidget {
  const _ZonePill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(
                  painter: FeedHexClusterPainter(color: color, compact: true),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MixBadge extends StatelessWidget {
  const _MixBadge({required this.localPct, required this.visitorPct});

  final int localPct;
  final int visitorPct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Locals $localPct%  |  Visitors $visitorPct%',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF166534),
        ),
      ),
    );
  }
}

class _PulseMixBar extends StatelessWidget {
  const _PulseMixBar({required this.localPct, required this.visitorPct});

  final int localPct;
  final int visitorPct;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (localPct > 0)
                  Expanded(
                    flex: localPct,
                    child: const ColoredBox(color: TravelerGradient.local),
                  ),
                if (visitorPct > 0)
                  Expanded(
                    flex: visitorPct,
                    child: const ColoredBox(
                      color: TravelerGradient.international,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Locals $localPct%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
            const Spacer(),
            const Text(
              'vs',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: feedMuted,
              ),
            ),
            const Spacer(),
            Text(
              'Visitors $visitorPct%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.liked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onPin,
  });

  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Like',
          onPressed: onLike,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: liked ? const Color(0xFFEF4444) : feedMuted,
          ),
        ),
        IconButton(
          tooltip: 'Ask this area',
          onPressed: onComment,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chat_bubble_outline, size: 20, color: feedMuted),
        ),
        IconButton(
          tooltip: 'View on map',
          onPressed: onShare,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.sync_alt, size: 20, color: feedMuted),
        ),
        IconButton(
          tooltip: 'Open zone',
          onPressed: onPin,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.location_on_outlined, size: 20, color: feedMuted),
        ),
      ],
    );
  }
}

class _NestedReply extends StatelessWidget {
  const _NestedReply({required this.reply});

  final FeedReply reply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorAvatar(handle: reply.authorHandle),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Community replies',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: feedInk,
                  ),
                ),
                Text(
                  reply.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w600,
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

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onOpenMap, required this.onAddTag});

  final VoidCallback onOpenMap;
  final VoidCallback onAddTag;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz, color: feedMuted),
      onSelected: (value) {
        if (value == 'map') onOpenMap();
        if (value == 'tag') onAddTag();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'map', child: Text('View on map')),
        PopupMenuItem(value: 'tag', child: Text('Add a tag here')),
      ],
    );
  }
}

class FeedHexClusterPainter extends CustomPainter {
  FeedHexClusterPainter({required this.color, this.compact = false});

  final Color color;
  final bool compact;

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
    final r = compact ? size.width / 3.2 : size.width / 4.2;
    final hexWidth = r * math.sqrt(3);
    final hexHeight = r * 1.5;
    final lightFill = Paint()..color = color.withValues(alpha: 0.18);
    final lightStroke = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final mainFill = Paint()..color = color.withValues(alpha: 0.9);
    final mainStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    if (!compact) {
      for (final offset in [
        Offset(-hexWidth, 0),
        Offset(hexWidth, 0),
        Offset(-hexWidth / 2, -hexHeight),
        Offset(hexWidth / 2, -hexHeight),
        Offset(-hexWidth / 2, hexHeight),
        Offset(hexWidth / 2, hexHeight),
      ]) {
        _hex(canvas, center + offset, r * 0.52, lightFill, lightStroke);
      }
    }
    _hex(canvas, center, compact ? r : r * 0.7, mainFill, mainStroke);
  }

  @override
  bool shouldRepaint(covariant FeedHexClusterPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.compact != compact;
}
