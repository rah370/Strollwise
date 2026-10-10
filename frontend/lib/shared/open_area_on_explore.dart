import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'models/zone.dart';
import 'providers/app_providers.dart';
import 'traveler_gradient.dart';

/// Shared Explore jump used after tag submit, Recent tags, and Saved zones.
void openAreaOnExplore(
  WidgetRef ref,
  BuildContext context, {
  required LatLng focus,
  ZoneModel? zone,
  String? title,
  String? submitSummary,
}) {
  final enriched = zone == null ? null : enrichZoneForAreaCard(zone);
  if (enriched != null) {
    ref.read(selectedZoneProvider.notifier).state = enriched;
    ref.invalidate(selectedZoneDetailProvider);
  }
  ref.read(zoneLookupLocationProvider.notifier).state = focus;
  ref.read(exploreFocusLocationProvider.notifier).state = focus;
  if (title != null && title.trim().isNotEmpty) {
    ref.read(mapSearchPlaceTitleProvider.notifier).state = title.trim();
    ref.read(mapSearchFocusProvider.notifier).state = focus;
  }
  if (submitSummary != null && submitSummary.trim().isNotEmpty) {
    ref.read(tagSubmittedBannerProvider.notifier).state = TagSubmittedBanner(
      message: submitSummary.trim(),
      shownAt: DateTime.now(),
    );
    ref.read(explorePostSubmitCueProvider.notifier).state = ExplorePostSubmitCue(
      focus: focus,
      summary: submitSummary.trim(),
      zone: enriched,
      placeTitle: title,
    );
  } else {
    ref.read(exploreFlashPinProvider.notifier).state = focus;
  }
  context.go('/explore');
}
