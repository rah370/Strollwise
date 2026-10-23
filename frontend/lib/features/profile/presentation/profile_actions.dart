import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/data/origin_locations.dart';
import '../../../shared/h3_location.dart';
import '../../../shared/location/cebu_place_geocode.dart';
import '../../../shared/models/report.dart';
import '../../../shared/models/user_me.dart';
import '../../../shared/models/visit_pin.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/network/api_client.dart';
import '../../../shared/notifications/app_notifications.dart';
import '../../../shared/open_area_on_explore.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/traveler_gradient.dart';
import '../../../shared/user_manual_map_location.dart';
import '../../../shared/widgets/origin_location_picker.dart';
import '../../../shared/zone_place_ui.dart';
import '../profile_copy.dart';

Future<void> refreshProfileData(WidgetRef ref) async {
  final token = ref.read(authTokenProvider);
  if (isLocalDemoSession(token)) return;
  ref.invalidate(userMeProvider);
  ref.invalidate(savedZonesProfileProvider);
  ref.invalidate(ownVisitHistoryProvider);
  await ref.read(userContributionsProvider.notifier).refresh();
  try {
    await ref.read(userMeProvider.future);
  } catch (_) {}
  try {
    await ref.read(savedZonesProfileProvider.future);
  } catch (_) {}
}

void openVisitOnExplore(
  WidgetRef ref,
  BuildContext context,
  VisitPinModel pin,
) {
  final location = LatLng(pin.latitude, pin.longitude);
  ref.read(selectedZoneProvider.notifier).state = null;
  ref.read(mapSearchFocusProvider.notifier).state = location;
  ref.read(mapSearchPlaceTitleProvider.notifier).state =
      pin.label ?? 'Visited spot';
  ref.read(exploreFocusLocationProvider.notifier).state = location;
  ref.invalidate(currentZoneOverviewProvider);
  context.go('/explore');
}

Future<void> openReportOnExplore(
  WidgetRef ref,
  BuildContext context,
  ReportModel report,
) async {
  final focus = latLngForReport(report);
  if (focus == null) {
    pushAppNotification(
      ref,
      title: 'Could not open tag',
      message: 'This tag has no map location yet. Try again after refresh.',
      kind: AppNotificationKind.warning,
    );
    return;
  }
  await ZoneCatalog.ensureLoaded();
  final entry = ZoneCatalog.nearestEntryWithin(focus.latitude, focus.longitude);
  final zone = entry == null ? null : zoneModelFromCatalogEntry(entry);
  final presented = presentProfileTag(
    report,
    placeName: entry?.zoneName,
    neighborhood: entry?.city,
  );
  if (!context.mounted) return;
  openAreaOnExplore(
    ref,
    context,
    focus: focus,
    zone: zone,
    title: zone == null ? presented.title : zoneDisplayTitle(zone),
  );
}

void openSavedZoneOnExplore(
  WidgetRef ref,
  BuildContext context,
  ZoneModel zone,
) {
  final focus = (zone.centroidLat == 0.0 && zone.centroidLng == 0.0)
      ? null
      : LatLng(zone.centroidLat, zone.centroidLng);
  if (focus == null) {
    pushAppNotification(
      ref,
      title: 'Could not open zone',
      message: 'This saved place has no map point yet.',
      kind: AppNotificationKind.warning,
    );
    return;
  }
  openAreaOnExplore(
    ref,
    context,
    focus: focus,
    zone: zone,
    title: zoneDisplayTitle(zone),
  );
}

void showVerifiedExplanationDialog(
  BuildContext context, {
  required bool isAdmin,
  required bool researchConsent,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Verified mark'),
      content: Text(
        verifiedBadgeExplanation(
          isAdmin: isAdmin,
          researchConsent: researchConsent,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showBadgeSheet(BuildContext context, ProfileBadgeInfo badge, bool earned) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              badge.label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              earned ? badge.earnedCopy : badge.howToEarn,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            if (earned) ...[
              const SizedBox(height: 10),
              Text(
                'How it is earned: ${badge.howToEarn}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

Future<void> showLogoutConfirm(BuildContext context, WidgetRef ref) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Log out'),
      content: const Text('End your current StrollWise session?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (shouldLogout != true || !context.mounted) return;
  await ref.read(authActionProvider.notifier).logout();
  if (!context.mounted) return;
  context.go('/auth');
}

class ProfileEditResult {
  const ProfileEditResult({
    required this.displayName,
    required this.country,
    required this.city,
    required this.userType,
  });

  final String displayName;
  final String country;
  final String city;
  final String userType;
}

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({
    super.key,
    required this.initialName,
    required this.initialCountry,
    required this.initialCity,
    required this.initialUserType,
  });

  final String initialName;
  final String initialCountry;
  final String initialCity;
  final String initialUserType;

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  static const _userTypeChoices = <(String, String)>[
    ('local_resident', 'Local resident'),
    ('international_visitor', 'International visitor'),
    ('domestic_traveler', 'Domestic traveler'),
  ];

  late final TextEditingController _nameController;
  late String _country;
  late String _city;
  late String _userType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    final resolved = OriginLocationCatalog.resolveSelection(
      country: widget.initialCountry,
      city: widget.initialCity,
    );
    _country = resolved.country;
    _city = resolved.city;
    _userType = widget.initialUserType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                helperText: 'Saved to your StrollWise account',
              ),
            ),
            const SizedBox(height: 12),
            OriginLocationPicker(
              dense: true,
              country: _country,
              city: _city,
              onCountryChanged: (value) => setState(() => _country = value),
              onCityChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _userTypeChoices.any((e) => e.$1 == _userType)
                  ? _userType
                  : 'local_resident',
              decoration: const InputDecoration(labelText: 'User type'),
              items: _userTypeChoices
                  .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _userType = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ProfileEditResult(
              displayName: _nameController.text,
              country: _country,
              city: _city,
              userType: _userType,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<void> editProfile(BuildContext context, WidgetRef ref) async {
  final token = ref.read(authTokenProvider);
  if (isLocalDemoSession(token)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign in with a full account to edit your profile.'),
      ),
    );
    return;
  }
  UserMeModel? user = ref.read(cachedUserMeProvider);
  user ??= await ref.read(userMeProvider.future);
  if (!context.mounted) return;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not load profile. Pull to refresh.')),
    );
    return;
  }
  final u = user;
  final result = await showDialog<ProfileEditResult>(
    context: context,
    builder: (_) => EditProfileDialog(
      initialName: u.displayName?.trim().isNotEmpty == true
          ? u.displayName!.trim()
          : displayNameFromEmail(u.email),
      initialCountry: u.countryOfOrigin ?? '',
      initialCity: u.cityOfOrigin ?? '',
      initialUserType: u.userType ?? 'local_resident',
    ),
  );
  if (!context.mounted) return;
  if (result == null) return;
  final name = result.displayName.trim();
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Display name is required.')),
    );
    return;
  }
  if (!OriginLocationCatalog.isValidPair(result.country, result.city)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Choose a valid country and city from the lists.'),
      ),
    );
    return;
  }
  try {
    await ref.read(dioProvider).patch(
      '/users/me',
      data: {
        'display_name': name,
        'country_of_origin': result.country.trim(),
        'city_of_origin': result.city.trim(),
        'user_type': result.userType,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;
    ref.invalidate(userMeProvider);
    try {
      await ref.read(userMeProvider.future);
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile. Try again.')),
      );
    }
  }
}

Future<void> setManualLocationFromProfile(
  BuildContext context,
  WidgetRef ref,
) async {
  final queryController = TextEditingController();
  var busy = false;

  Future<void> tryApply(
    BuildContext dialogCtx,
    void Function(void Function()) setLocal,
  ) async {
    final q = queryController.text.trim();
    if (q.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter an area, street, or landmark.')),
        );
      }
      return;
    }
    setLocal(() => busy = true);
    try {
      final found = await geocodeCebuPlace(ref.read(dioProvider), q);
      if (!dialogCtx.mounted) return;
      if (found == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No match in greater Cebu. Try another spelling or a shorter name.',
              ),
            ),
          );
        }
        if (dialogCtx.mounted) {
          setLocal(() => busy = false);
        }
        return;
      }
      Navigator.of(dialogCtx).pop(found);
    } catch (_) {
      if (dialogCtx.mounted) {
        setLocal(() => busy = false);
      }
    }
  }

  LatLng? result;
  try {
    result = await showDialog<LatLng>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text('Change map location'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Search for a place in greater Cebu — neighborhood, '
                    'street, mall, campus, or landmark.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedText.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: queryController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Place or street',
                      hintText: 'e.g. Ayala Center, Colon Street, USPF',
                    ),
                    onSubmitted: (_) {
                      if (!busy) unawaited(tryApply(ctx, setLocal));
                    },
                  ),
                  if (busy) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => unawaited(tryApply(ctx, setLocal)),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    queryController.dispose();
  }

  if (result == null) return;
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) return;

  final token = ref.read(authTokenProvider);
  final isDemo = isLocalDemoSession(token);
  if (!isDemo) {
    final saved = await persistUserManualMapLocation(ref, result);
    if (!context.mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save location to your account. Check your connection.',
          ),
        ),
      );
      return;
    }
  }
  ref.read(currentUserLocationProvider.notifier).state = result;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isDemo
            ? 'Saved on this device for Explore and nearby picks.'
            : 'Saved to your account. Explore and feeds will use this place.',
      ),
    ),
  );
}
