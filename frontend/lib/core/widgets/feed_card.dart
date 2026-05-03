import 'package:flutter/material.dart';

class FeedCard extends StatelessWidget {
  const FeedCard({
    required this.category,
    required this.note,
    required this.timeLabel,
    super.key,
  });

  final String category;
  final String note;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(category.toUpperCase()),
        subtitle: Text(note),
        trailing: Text(
          timeLabel,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
