import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/providers/app_providers.dart';

/// WHO (traveler mix) + WHAT (place type) filter chips and map legend.
class ExploreMapFilters extends ConsumerWidget {
  const ExploreMapFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traveler = ref.watch(activeTravelerMixFilterProvider);
    final placeType = ref.watch(activePlaceTypeFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterSection(
          title: 'Who uses this area',
          child: _ChipRow(
            chips: const [
              _FilterChipSpec(
                label: 'Local',
                value: 'local',
                icon: Icons.groups_rounded,
                accent: AppColors.travelerLocal,
                fill: AppColors.localFill,
              ),
              _FilterChipSpec(
                label: 'Mixed',
                value: 'mixed',
                icon: Icons.hub_outlined,
                accent: AppColors.travelerMixed,
                fill: AppColors.mixedFill,
              ),
              _FilterChipSpec(
                label: 'International',
                value: 'international',
                icon: Icons.flight_takeoff_rounded,
                accent: AppColors.travelerInternational,
                fill: AppColors.touristFill,
              ),
            ],
            selected: traveler,
            onSelected: (value) {
              ref.read(activeTravelerMixFilterProvider.notifier).state =
                  traveler == value ? null : value;
            },
          ),
        ),
        const SizedBox(height: 8),
        _FilterSection(
          title: 'What this place is',
          child: _ChipRow(
            chips: const [
              _FilterChipSpec(
                label: 'School',
                value: 'school',
                icon: Icons.school_outlined,
                accent: AppColors.zoneSchool,
                fill: Color(0xFFF0E4FF),
              ),
              _FilterChipSpec(
                label: 'Food',
                value: 'food',
                icon: Icons.restaurant_outlined,
                accent: AppColors.zoneFood,
                fill: AppColors.foodFill,
              ),
              _FilterChipSpec(
                label: 'Transport',
                value: 'transport',
                icon: Icons.directions_bus_outlined,
                accent: AppColors.zoneTransport,
                fill: AppColors.transportFill,
              ),
              _FilterChipSpec(
                label: 'Commercial',
                value: 'commercial',
                icon: Icons.business_outlined,
                accent: AppColors.zoneCommercial,
                fill: AppColors.commercialFill,
              ),
            ],
            selected: placeType,
            onSelected: (value) {
              ref.read(activePlaceTypeFilterProvider.notifier).state =
                  placeType == value ? null : value;
            },
          ),
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _FilterChipSpec {
  const _FilterChipSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.fill,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color fill;
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.chips,
    required this.selected,
    required this.onSelected,
  });

  final List<_FilterChipSpec> chips;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isSelected = selected == chip.value;
          return Material(
            color: isSelected
                ? chip.fill.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelected(chip.value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? chip.accent : AppColors.border,
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      chip.icon,
                      size: 14,
                      color: isSelected ? chip.accent : AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      chip.label,
                      style: TextStyle(
                        color: isSelected
                            ? chip.accent
                            : AppColors.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
