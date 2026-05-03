import 'package:flutter/material.dart';

class ZoneStatsCard extends StatelessWidget {
  const ZoneStatsCard({required this.title, required this.value, super.key});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title), const SizedBox(height: 8), Text(value)],
        ),
      ),
    );
  }
}
