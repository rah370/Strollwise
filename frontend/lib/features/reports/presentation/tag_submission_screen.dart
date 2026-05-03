import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/current_zone_overview.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/app_providers.dart';

class TagSubmissionScreen extends ConsumerStatefulWidget {
  const TagSubmissionScreen({super.key});

  @override
  ConsumerState<TagSubmissionScreen> createState() =>
      _TagSubmissionScreenState();
}

class _TagSubmissionScreenState extends ConsumerState<TagSubmissionScreen> {
  static const _cebuCityCenter = LatLng(10.3157, 123.8854);

  static const _tagTypes = [
    _TagType(
      backendCategory: 'food',
      label: 'Food',
      icon: Icons.restaurant_outlined,
      accent: Color(0xFF34765B),
      fill: Color(0xFFF2FBF6),
      details: ['Street Food', 'Cafe', 'Restaurant', 'Late Night'],
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Tourist',
      icon: Icons.photo_camera_outlined,
      accent: Color(0xFF7BA0E6),
      fill: Color(0xFFF3F7FF),
      details: ['Photo Spot', 'Landmark', 'Visitor Friendly', 'Scenic'],
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Local Pick',
      icon: Icons.star_border_rounded,
      accent: Color(0xFF78BE9C),
      fill: Color(0xFFF1FBF5),
      details: ['Neighborhood Favorite', 'Budget Meal', 'Worth Detour', 'Calm'],
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Residential',
      icon: Icons.home_outlined,
      accent: Color(0xFF8F73EC),
      fill: Color(0xFFF7F3FF),
      details: ['Quiet', 'Family Area', 'Mostly Locals', 'Side Streets'],
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Commercial',
      icon: Icons.business_outlined,
      accent: Color(0xFFF0A127),
      fill: Color(0xFFFFF8EE),
      details: ['Mall Area', 'Offices', 'Busy', 'Open Late'],
    ),
    _TagType(
      backendCategory: 'school',
      label: 'School',
      icon: Icons.school_outlined,
      accent: Color(0xFF8060E8),
      fill: Color(0xFFF7F3FF),
      details: [
        'Study Friendly',
        'Student Budget',
        'After Class',
        'Campus Edge',
      ],
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Hotel',
      icon: Icons.hotel_outlined,
      accent: Color(0xFF69A6E8),
      fill: Color(0xFFF1F8FF),
      details: ['Near Lobby', 'Visitor Pickup', 'Quiet Stay', 'Walkable'],
    ),
    _TagType(
      backendCategory: 'transport',
      label: 'Transport',
      icon: Icons.directions_bus_outlined,
      accent: Color(0xFF65B9BE),
      fill: Color(0xFFF1FBFB),
      details: ['Near Transit', 'Pickup Point', 'Traffic', 'Easy Crossing'],
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Nature',
      icon: Icons.eco_outlined,
      accent: Color(0xFF5FA864),
      fill: Color(0xFFF3FBF3),
      details: ['Shade', 'Green Space', 'Fresh Air', 'Quiet Walk'],
    ),
    _TagType(
      backendCategory: 'safety',
      label: 'Safety',
      icon: Icons.shield_outlined,
      accent: Color(0xFFE45E53),
      fill: Color(0xFFFFF3F2),
      details: ['Well Lit', 'Avoid Late', 'Police Nearby', 'Crowded Exit'],
    ),
    _TagType(
      backendCategory: 'activity',
      label: 'Activity',
      icon: Icons.directions_run_rounded,
      accent: Color(0xFFE3A128),
      fill: Color(0xFFFFF8EE),
      details: ['Nightlife', 'Great Place', 'Good for Groups', 'Live Music'],
    ),
  ];

  final noteController = TextEditingController();
  String _selectedTypeLabel = _tagTypes.first.label;
  String _selectedVisibility = 'Anonymous';
  String _selectedDetail = _tagTypes.first.details.first;
  bool _isResolvingLocation = false;

  _TagType get _selectedType =>
      _tagTypes.firstWhere((type) => type.label == _selectedTypeLabel);

  bool get _canSubmit =>
      _selectedDetail.isNotEmpty || noteController.text.trim().isNotEmpty;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isResolvingLocation = true);
    Position? position;
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (isEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          );
        }
      }
    } catch (_) {
      // Fall back to current map center if GPS lookup fails.
    } finally {
      if (mounted) setState(() => _isResolvingLocation = false);
    }

    final center = ref.read(mapViewportProvider).center;
    final tags = <String>[
      if (_selectedDetail.isNotEmpty) _selectedDetail.toLowerCase(),
      _selectedType.label.toLowerCase(),
      _selectedVisibility.toLowerCase(),
    ];

    final payload = TagSubmissionPayload(
      latitude: position?.latitude ?? center.latitude,
      longitude: position?.longitude ?? center.longitude,
      category: _selectedType.backendCategory,
      tags: tags,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );

    try {
      await ref.read(tagSubmissionProvider.notifier).submit(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tag submitted.')));
      setState(() {
        _selectedTypeLabel = _tagTypes.first.label;
        _selectedDetail = _tagTypes.first.details.first;
        _selectedVisibility = 'Anonymous';
        noteController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submission failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = ref.watch(tagSubmissionProvider);
    final selectedZone = ref.watch(selectedZoneProvider);
    final currentZoneOverview = ref.watch(currentZoneOverviewProvider);
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final selectedType = _selectedType;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: currentZoneOverview.when(
        data: (overview) => _AddTagScene(
          selectedType: selectedType,
          selectedDetail: _selectedDetail,
          selectedVisibility: _selectedVisibility,
          noteController: noteController,
          selectedZone: selectedZone,
          overview: overview,
          isLoading: submissionState.isLoading || _isResolvingLocation,
          safeBottom: safeBottom,
          onBack: () => context.go('/explore'),
          onTypeSelected: (type) => setState(() {
            _selectedTypeLabel = type.label;
            if (!type.details.contains(_selectedDetail)) {
              _selectedDetail = type.details.first;
            }
          }),
          onDetailSelected: (detail) =>
              setState(() => _selectedDetail = detail),
          onVisibilitySelected: (value) =>
              setState(() => _selectedVisibility = value),
          onSubmit: _canSubmit ? _submit : null,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _AddTagScene(
          selectedType: selectedType,
          selectedDetail: _selectedDetail,
          selectedVisibility: _selectedVisibility,
          noteController: noteController,
          selectedZone: selectedZone,
          overview: null,
          isLoading: submissionState.isLoading || _isResolvingLocation,
          safeBottom: safeBottom,
          onBack: () => context.go('/explore'),
          onTypeSelected: (type) => setState(() {
            _selectedTypeLabel = type.label;
            if (!type.details.contains(_selectedDetail)) {
              _selectedDetail = type.details.first;
            }
          }),
          onDetailSelected: (detail) =>
              setState(() => _selectedDetail = detail),
          onVisibilitySelected: (value) =>
              setState(() => _selectedVisibility = value),
          onSubmit: _canSubmit ? _submit : null,
        ),
      ),
    );
  }
}

class _AddTagScene extends StatelessWidget {
  const _AddTagScene({
    required this.selectedType,
    required this.selectedDetail,
    required this.selectedVisibility,
    required this.noteController,
    required this.selectedZone,
    required this.overview,
    required this.isLoading,
    required this.safeBottom,
    required this.onBack,
    required this.onTypeSelected,
    required this.onDetailSelected,
    required this.onVisibilitySelected,
    required this.onSubmit,
  });

  final _TagType selectedType;
  final String selectedDetail;
  final String selectedVisibility;
  final TextEditingController noteController;
  final ZoneModel? selectedZone;
  final CurrentZoneOverviewModel? overview;
  final bool isLoading;
  final double safeBottom;
  final VoidCallback onBack;
  final ValueChanged<_TagType> onTypeSelected;
  final ValueChanged<String> onDetailSelected;
  final ValueChanged<String> onVisibilitySelected;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final zone = selectedZone ?? overview?.currentZone;
    final mapLabels = _buildMapLabels(zone, overview);
    final noteLength = noteController.text.length;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                _FloatingCircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Add Tag',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                const _AvatarBubble(
                  color: AppColors.primaryAction,
                  icon: Icons.person,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                const Positioned.fill(child: _StaticMapBackdrop()),
                const Positioned.fill(child: _MapGlowOverlay()),
                ...mapLabels,
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, safeBottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contribute what this area is known for.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CurrentZoneCard(zone: zone),
                  const SizedBox(height: 18),
                  const _SectionLabel('Tag Type'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _TagSubmissionScreenState._tagTypes
                        .map(
                          (type) => _TypeChip(
                            type: type,
                            selected: type.label == selectedType.label,
                            onTap: () => onTypeSelected(type),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Optional Detail'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: selectedType.details
                        .map(
                          (detail) => _PillChoiceChip(
                            label: detail,
                            selected: detail == selectedDetail,
                            onTap: () => onDetailSelected(detail),
                            accent: selectedType.accent,
                            selectedFill: selectedType.fill,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Add a note'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: noteController,
                          maxLength: 120,
                          maxLines: 2,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(120),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Best for affordable food at night',
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isCollapsed: true,
                            filled: false,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$noteLength/120',
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Visibility'),
                  const SizedBox(height: 10),
                  _VisibilitySelector(
                    selectedVisibility: selectedVisibility,
                    onVisibilitySelected: onVisibilitySelected,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onSubmit,
                      icon: Icon(
                        isLoading
                            ? Icons.my_location_rounded
                            : Icons.send_rounded,
                      ),
                      label: Text(
                        isLoading ? 'Getting location...' : 'Submit Tag',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tags are reviewed and released in batch after validation.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

List<Widget> _buildMapLabels(
  ZoneModel? current,
  CurrentZoneOverviewModel? overview,
) {
  final labels = <Widget>[];
  final candidates = <ZoneModel>[
    ...[current].whereType<ZoneModel>(),
    ...?overview?.nearbyZones.take(3),
  ];
  if (candidates.isEmpty) {
    return const [
      Positioned(
        top: 118,
        left: 395,
        child: _MapZoneGhost(
          width: 160,
          height: 128,
          borderColor: AppColors.zoneFood,
          title: 'IT Park',
          subtitle: 'Food Hotspot',
          textColor: AppColors.foodAccent,
        ),
      ),
      Positioned(
        top: 208,
        left: 250,
        child: _MapZoneGhost(
          width: 150,
          height: 126,
          borderColor: AppColors.zoneSchool,
          title: 'USC Main',
          subtitle: 'Student Area',
          textColor: AppColors.studentAccent,
        ),
      ),
      Positioned(
        top: 68,
        left: 240,
        child: Text(
          'Lahug',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];
  }

  final positions = <({double top, double left})>[
    (top: 118, left: 390),
    (top: 212, left: 250),
    (top: 84, left: 255),
  ];

  for (var i = 0; i < math.min(candidates.length, positions.length); i++) {
    final zone = candidates[i];
    final palette = _zonePalette(zone);
    final title = _zoneTitle(zone);
    final subtitle = _zoneIdentity(zone);
    final position = positions[i];
    if (i == 2) {
      labels.add(
        Positioned(
          top: position.top,
          left: position.left,
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    } else {
      labels.add(
        Positioned(
          top: position.top,
          left: position.left,
          child: _MapZoneGhost(
            width: i == 0 ? 162 : 152,
            height: i == 0 ? 130 : 126,
            borderColor: palette.border,
            title: title,
            subtitle: subtitle,
            textColor: palette.accent,
          ),
        ),
      );
    }
  }

  return labels;
}

class _StaticMapBackdrop extends StatelessWidget {
  const _StaticMapBackdrop();

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: _TagSubmissionScreenState._cebuCityCenter,
        zoom: 12.5,
      ),
      styleString:
          'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      myLocationEnabled: false,
      onMapCreated: (_) {},
    );
  }
}

class _MapGlowOverlay extends StatelessWidget {
  const _MapGlowOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.70),
              Colors.white.withValues(alpha: 0.38),
              Colors.white.withValues(alpha: 0.10),
              Colors.white,
            ],
            stops: const [0, 0.36, 0.72, 1],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 58,
          child: Center(
            child: Icon(icon, size: 32, color: AppColors.primaryText),
          ),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
      ),
      child: Center(child: Icon(icon, color: color, size: 30)),
    );
  }
}

class _MapZoneGhost extends StatelessWidget {
  const _MapZoneGhost({
    required this.width,
    required this.height,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.textColor,
  });

  final double width;
  final double height;
  final Color borderColor;
  final String title;
  final String subtitle;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _HexOutlinePainter(borderColor),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HexOutlinePainter extends CustomPainter {
  const _HexOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width * 0.28, 0);
    path.lineTo(size.width * 0.72, 0);
    path.lineTo(size.width, size.height * 0.32);
    path.lineTo(size.width * 0.72, size.height);
    path.lineTo(size.width * 0.28, size.height);
    path.lineTo(0, size.height * 0.68);
    path.lineTo(0, size.height * 0.32);
    path.close();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.45);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CurrentZoneCard extends StatelessWidget {
  const _CurrentZoneCard({required this.zone});

  final ZoneModel? zone;

  @override
  Widget build(BuildContext context) {
    final title = zone == null
        ? 'Zone unavailable'
        : '${_zoneTitle(zone!)} Area';
    final subtitle = zone == null
        ? 'Move or refresh location to detect your zone.'
        : _zoneIdentity(zone!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF6EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: AppColors.primaryAction,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Zone',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryAction,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2FAF5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.hexagon_outlined,
              size: 18,
              color: AppColors.primaryAction,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryText,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final _TagType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? type.fill : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? type.accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 23, color: type.accent),
            const SizedBox(width: 12),
            Text(
              type.label,
              style: TextStyle(
                color: selected ? AppColors.primaryText : type.accent,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillChoiceChip extends StatelessWidget {
  const _PillChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.selectedFill,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color selectedFill;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? selectedFill : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : const Color(0xFF667085),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5FBF7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.localAccent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF667085)),
            const SizedBox(width: 6),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: selected
                    ? AppColors.localAccent
                    : const Color(0xFF667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({
    required this.selectedVisibility,
    required this.onVisibilitySelected,
  });

  final String selectedVisibility;
  final ValueChanged<String> onVisibilitySelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final chips = [
          _VisibilityChip(
            label: 'Public',
            icon: Icons.public,
            selected: selectedVisibility == 'Public',
            onTap: () => onVisibilitySelected('Public'),
          ),
          _VisibilityChip(
            label: 'Anonymous',
            icon: Icons.face_3_outlined,
            selected: selectedVisibility == 'Anonymous',
            onTap: () => onVisibilitySelected('Anonymous'),
          ),
          _VisibilityChip(
            label: 'Private',
            icon: Icons.lock_outline_rounded,
            selected: selectedVisibility == 'Private',
            onTap: () => onVisibilitySelected('Private'),
          ),
        ];
        if (compact) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (chip) => SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: chip,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: [
            Expanded(child: chips[0]),
            const SizedBox(width: 8),
            Expanded(child: chips[1]),
            const SizedBox(width: 8),
            Expanded(child: chips[2]),
          ],
        );
      },
    );
  }
}

class _TagType {
  const _TagType({
    required this.backendCategory,
    required this.label,
    required this.icon,
    required this.accent,
    required this.fill,
    required this.details,
  });

  final String backendCategory;
  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
  final List<String> details;
}

String _zoneTitle(ZoneModel zone) {
  final name = zone.displayName.trim();
  if (name.isNotEmpty) {
    final nearIdx = name.toLowerCase().lastIndexOf(' near ');
    if (nearIdx >= 0 && nearIdx + 6 < name.length) {
      return name.substring(nearIdx + 6).trim();
    }
    return name;
  }
  final type = zone.zoneType.toLowerCase();
  if (type.contains('food')) return 'IT Park';
  if (type.contains('transport')) return 'Port Area';
  if (type.contains('school')) return 'USC Main';
  if (type.contains('commercial')) return 'Ayala Center';
  if (type.contains('residential')) return 'Lahug';
  return 'Cebu City';
}

String _zoneIdentity(ZoneModel zone) {
  final type = zone.zoneType.toLowerCase();
  if (type.contains('food')) return 'Food Hotspot';
  if (type.contains('transport')) return 'Transport';
  if (type.contains('school')) return 'Student Area';
  if (type.contains('commercial')) return 'Commercial';
  if (type.contains('residential')) return 'Residential';
  if (type.contains('safety')) return 'Safety';
  return 'Local Pick';
}

_ZonePalette _zonePalette(ZoneModel zone) {
  final type = zone.zoneType.toLowerCase();
  if (type.contains('food')) {
    return const _ZonePalette(
      fill: AppColors.foodFill,
      border: AppColors.zoneFood,
      accent: AppColors.foodAccent,
    );
  }
  if (type.contains('school')) {
    return const _ZonePalette(
      fill: AppColors.studentFill,
      border: AppColors.zoneSchool,
      accent: AppColors.studentAccent,
    );
  }
  if (type.contains('transport')) {
    return const _ZonePalette(
      fill: AppColors.transportFill,
      border: AppColors.zoneTransport,
      accent: AppColors.transportAccent,
    );
  }
  if (type.contains('commercial')) {
    return const _ZonePalette(
      fill: AppColors.commercialFill,
      border: AppColors.zoneCommercial,
      accent: AppColors.commercialAccent,
    );
  }
  if (type.contains('residential')) {
    return const _ZonePalette(
      fill: AppColors.residentialFill,
      border: AppColors.zoneResidential,
      accent: AppColors.zoneResidential,
    );
  }
  if (type.contains('safety')) {
    return const _ZonePalette(
      fill: AppColors.safetyFill,
      border: AppColors.safetyBorder,
      accent: AppColors.safetyAccent,
    );
  }
  return const _ZonePalette(
    fill: AppColors.localFill,
    border: AppColors.travelerLocal,
    accent: AppColors.localAccent,
  );
}

class _ZonePalette {
  const _ZonePalette({
    required this.fill,
    required this.border,
    required this.accent,
  });

  final Color fill;
  final Color border;
  final Color accent;
}
