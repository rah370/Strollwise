import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/visit_pin.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/traveler_gradient.dart';
import '../../../shared/zone_place_ui.dart';
import '../profile_copy.dart';
import 'profile_actions.dart';
import 'profile_widgets.dart';

class VisitHistoryScreen extends ConsumerWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(ownVisitHistoryProvider);
    final savedZones = ref.watch(savedZonesProfileProvider);
    final savedList = savedZones.maybeWhen(
      data: (z) => z,
      orElse: () => const <ZoneModel>[],
    );

    return ProfileSubpageScaffold(
      title: 'Visit History',
      body: RefreshIndicator(
        color: AppColors.primaryAction,
        onRefresh: () => refreshProfileData(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              kVisitHistoryPrivacyCopy,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const ProfileSectionHeader(title: 'Private pins'),
            const SizedBox(height: 8),
            visits.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => const ProfilePanel(
                child: Text(
                  'Could not load your visit map.',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              data: (pins) {
                if (pins.isEmpty) {
                  return const ProfilePanel(
                    child: Text(
                      'No private pins yet. On Explore, tap the hiking icon to mark a place, or add a tag.',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  );
                }
                return ProfilePanel(
                  child: Column(
                    children: [
                      for (var i = 0; i < pins.length; i++) ...[
                        _VisitRow(
                          pin: pins[i],
                          onTap: () =>
                              openVisitOnExplore(ref, context, pins[i]),
                        ),
                        if (i < pins.length - 1)
                          const Divider(height: 12, color: AppColors.border),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ProfileSectionHeader(
              title: 'Saved places',
              actionLabel: savedList.isEmpty ? null : '${savedList.length}',
            ),
            const SizedBox(height: 8),
            ProfilePanel(
              child: savedList.isEmpty
                  ? const Text(
                      'No saved places yet.',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final zone in savedList)
                          ActionChip(
                            onPressed: () =>
                                openSavedZoneOnExplore(ref, context, zone),
                            avatar: Icon(
                              Icons.hexagon_outlined,
                              size: 16,
                              color: AppColors.primaryAction.withValues(
                                alpha: 0.85,
                              ),
                            ),
                            label: Text(
                              zoneDisplayTitle(zone),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.pin, required this.onTap});

  final VisitPinModel pin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = ZoneCatalog.nearestEntryWithin(pin.latitude, pin.longitude);
    final title = (entry?.zoneName.trim().isNotEmpty == true)
        ? entry!.zoneName.trim()
        : (pin.label?.trim().isNotEmpty == true
              ? pin.label!.trim()
              : 'Saved place');
    final city = (entry?.city.trim().isNotEmpty == true)
        ? entry!.city.trim()
        : 'Cebu City';
    final when = _formatVisitDate(pin.lastVisitedAt);
    final meta = pin.visitCount > 1 ? '$when · ${pin.visitCount} visits' : when;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.backgroundAlt,
                child: Icon(
                  Icons.hiking_rounded,
                  size: 16,
                  color: AppColors.mapInk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$city · $meta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'View on map',
                      style: TextStyle(
                        color: AppColors.touristAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatVisitDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}
