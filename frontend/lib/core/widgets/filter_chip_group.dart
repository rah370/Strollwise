import 'package:flutter/material.dart';

class FilterChipGroup extends StatelessWidget {
  const FilterChipGroup({
    required this.options,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => FilterChip(
              label: Text(option),
              selected: selected.contains(option),
              onSelected: (_) => onTap(option),
            ),
          )
          .toList(),
    );
  }
}
