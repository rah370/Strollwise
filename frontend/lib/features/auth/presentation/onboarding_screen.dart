import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2FE), Color(0xFFF8FAFC), Color(0xFFFFFBEB)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 720
                  ? 640.0
                  : constraints.maxWidth;
              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                    children: [
                      const _HeroHexMap(),
                      const SizedBox(height: 26),
                      Text(
                        'Understand the city by how people actually move.',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'StrollWise turns community reports into privacy-aware H3 zones so travelers can spot local, tourist-heavy, mixed, and emerging areas at a glance.',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          height: 1.45,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _ProfileCard(),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.go('/auth'),
                        icon: const Icon(Icons.hexagon_outlined),
                        label: const Text('Continue to Login'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/explore'),
                        child: const Text('Skip profile setup for now'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroHexMap extends StatelessWidget {
  const _HeroHexMap();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.mapInk,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HexFieldPainter())),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    color: AppColors.primaryAction,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hex-first city intelligence with no public raw traces.',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your lens',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _RoleChip(label: 'Local', selected: true),
              _RoleChip(label: 'International'),
              _RoleChip(label: 'Student'),
              _RoleChip(label: 'Visitor'),
            ],
          ),
          const SizedBox(height: 14),
          const TextField(
            decoration: InputDecoration(
              hintText: 'Nickname',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryAction : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.secondaryText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HexFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      AppColors.travelerLocal,
      AppColors.travelerInternational,
      AppColors.travelerMixed,
      AppColors.accent,
    ];
    const radius = 30.0;
    final hexWidth = radius * 1.732;
    final hexHeight = radius * 1.5;
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.26);

    var index = 0;
    for (var y = -radius; y < size.height + radius; y += hexHeight) {
      final row = (y / hexHeight).round();
      for (var x = -hexWidth; x < size.width + hexWidth; x += hexWidth) {
        final center = Offset(x + (row.isOdd ? hexWidth / 2 : 0), y);
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final angle = 1.0472 * i - 1.5708;
          final point = Offset(
            center.dx + radius * 0.9 * math.cos(angle),
            center.dy + radius * 0.9 * math.sin(angle),
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        fill.color = colors[index % colors.length].withValues(alpha: 0.26);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        index++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
