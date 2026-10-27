import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/location/cebu_place_geocode.dart';
import '../../../shared/models/report.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/network/api_client.dart';
import '../../../shared/notifications/app_notifications.dart';
import '../../../shared/models/sensitive_site.dart';
import '../../../shared/open_area_on_explore.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/zone_place_ui.dart';
import 'sensitive_site_preview.dart';

Future<LatLng?> _tagPickerTryCurrentGps() async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}

double _approxMeters(LatLng a, LatLng b) {
  final dLat = (a.latitude - b.latitude) * 111000;
  final dLng = (a.longitude - b.longitude) * 111000;
  return math.sqrt(dLat * dLat + dLng * dLng);
}

class TagSubmissionScreen extends ConsumerStatefulWidget {
  const TagSubmissionScreen({super.key});

  @override
  ConsumerState<TagSubmissionScreen> createState() =>
      _TagSubmissionScreenState();
}

class _TagSubmissionScreenState extends ConsumerState<TagSubmissionScreen> {
  static const _tagTypes = [
    _TagType(
      backendCategory: 'food',
      label: 'Food',
      icon: Icons.restaurant_outlined,
      accent: Color(0xFF34765B),
      fill: Color(0xFFF2FBF6),
      details: ['Street Food', 'Cafe', 'Restaurant', 'Late Night'],
      detailPrompt: 'What type of food?',
      primary: true,
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Attractions',
      icon: Icons.photo_camera_outlined,
      accent: Color(0xFF7BA0E6),
      fill: Color(0xFFF3F7FF),
      details: ['Photo Spot', 'Landmark', 'Visitor Friendly', 'Scenic'],
      detailPrompt: 'What kind of attraction?',
      primary: true,
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Local Favorite',
      icon: Icons.star_border_rounded,
      accent: Color(0xFF78BE9C),
      fill: Color(0xFFF1FBF5),
      details: ['Neighborhood Favorite', 'Budget Meal', 'Worth Detour', 'Calm'],
      detailPrompt: 'What makes it a favorite?',
      primary: true,
    ),
    _TagType(
      backendCategory: 'transport',
      label: 'Transport',
      icon: Icons.directions_bus_outlined,
      accent: Color(0xFF65B9BE),
      fill: Color(0xFFF1FBFB),
      details: ['Near Transit', 'Pickup Point', 'Traffic', 'Easy Crossing'],
      detailPrompt: 'What kind of transport?',
      primary: true,
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Nature',
      icon: Icons.eco_outlined,
      accent: Color(0xFF5FA864),
      fill: Color(0xFFF3FBF3),
      details: ['Shade', 'Green Space', 'Fresh Air', 'Quiet Walk'],
      detailPrompt: 'What kind of nature spot?',
      primary: true,
    ),
    _TagType(
      backendCategory: 'safety',
      label: 'Safety',
      icon: Icons.shield_outlined,
      accent: Color(0xFFE45E53),
      fill: Color(0xFFFFF3F2),
      details: ['Well Lit', 'Avoid Late', 'Police Nearby', 'Crowded Exit'],
      detailPrompt: 'What should people know?',
      primary: true,
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Residential',
      icon: Icons.home_outlined,
      accent: Color(0xFF8F73EC),
      fill: Color(0xFFF7F3FF),
      details: ['Quiet', 'Family Area', 'Mostly Locals', 'Side Streets'],
      detailPrompt: 'What kind of area?',
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Commercial',
      icon: Icons.business_outlined,
      accent: Color(0xFFF0A127),
      fill: Color(0xFFFFF8EE),
      details: ['Mall Area', 'Offices', 'Busy', 'Open Late'],
      detailPrompt: 'What kind of commercial spot?',
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
        'USPF campus',
      ],
      detailPrompt: 'What kind of school spot?',
    ),
    _TagType(
      backendCategory: 'other',
      label: 'Hotel',
      icon: Icons.hotel_outlined,
      accent: Color(0xFF69A6E8),
      fill: Color(0xFFF1F8FF),
      details: ['Near Lobby', 'Visitor Pickup', 'Quiet Stay', 'Walkable'],
      detailPrompt: 'What kind of hotel spot?',
    ),
    _TagType(
      backendCategory: 'activity',
      label: 'Activity',
      icon: Icons.directions_run_rounded,
      accent: Color(0xFFE3A128),
      fill: Color(0xFFFFF8EE),
      details: ['Nightlife', 'Great Place', 'Good for Groups', 'Live Music'],
      detailPrompt: 'What kind of activity?',
    ),
  ];

  final noteController = TextEditingController();
  final placeSearchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _locationKey = GlobalKey();
  final _categoryKey = GlobalKey();

  String? _selectedTypeLabel;
  final Set<String> _selectedDetails = {};
  bool _postAnonymously = true;
  bool _noteExpanded = false;
  bool _showMoreCategories = false;
  bool _locationEditing = true;
  String? _locationLabel;
  LatLng? _pickedLocation;
  bool _searchBusy = false;
  bool _gpsBusy = false;
  bool _ignoreSearch = false;
  List<CebuPlaceSearchHit> _placeHits = const [];
  String? _searchFeedback;
  Timer? _searchDebounce;
  int _searchRequestGen = 0;
  _TagSubmitConfirmation? _confirmation;
  String? _submitError;
  bool _openingSubmittedArea = false;

  @override
  void initState() {
    super.initState();
    placeSearchController.addListener(_onPlaceQueryChanged);
  }

  _TagType? get _selectedType {
    final label = _selectedTypeLabel;
    if (label == null) return null;
    for (final type in _tagTypes) {
      if (type.label == label) return type;
    }
    return null;
  }

  bool get _canSubmit => _pickedLocation != null && _selectedType != null;

  List<_TagType> get _visibleTypes => _showMoreCategories
      ? _tagTypes
      : _tagTypes.where((type) => type.primary).toList();

  void _applyLocation(LatLng location, {String? label}) {
    ref.read(tagSubmissionPinLocationProvider.notifier).state = location;
    setState(() {
      _pickedLocation = location;
      _locationEditing = false;
      _placeHits = const [];
      _searchFeedback = null;
      if (label != null && label.trim().isNotEmpty) {
        _locationLabel = label.trim();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    noteController.dispose();
    placeSearchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPlaceQueryChanged() {
    if (_ignoreSearch) return;
    _searchDebounce?.cancel();
    final query = placeSearchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _placeHits = const [];
        _searchFeedback = null;
        _searchBusy = false;
      });
      return;
    }
    setState(() {
      _searchBusy = true;
      _locationEditing = true;
    });
    final gen = ++_searchRequestGen;
    _searchDebounce = Timer(const Duration(milliseconds: 380), () async {
      final hits = await searchCebuPlaces(ref.read(dioProvider), query);
      if (!mounted || gen != _searchRequestGen) return;
      setState(() {
        _placeHits = hits;
        _searchBusy = false;
        _searchFeedback = hits.isEmpty
            ? 'No places found in Cebu for "$query".'
            : null;
      });
    });
  }

  void _selectPlaceHit(CebuPlaceSearchHit hit) {
    FocusScope.of(context).unfocus();
    _ignoreSearch = true;
    placeSearchController.text = hit.title;
    _ignoreSearch = false;
    _applyLocation(hit.location, label: hit.title);
  }

  Future<void> _submit() async {
    if (_pickedLocation == null) {
      _focusLocationPicker();
      return;
    }
    if (_selectedType == null) {
      _scrollTo(_categoryKey);
      return;
    }
    if (!_canSubmit) return;

    final sites = ref.read(sensitiveSitesProvider).valueOrNull ?? const [];
    final blocked = siteContaining(
      sites,
      _pickedLocation!.latitude,
      _pickedLocation!.longitude,
    );
    if (blocked != null) {
      setState(() => _submitError = pinOnBuildingCopy(blocked.kind));
      _scrollTo(_locationKey);
      return;
    }

    final submitLocation = _pickedLocation!;
    final selected = _selectedType!;
    final tags = <String>[
      for (final detail in _selectedDetails) detail.toLowerCase(),
      selected.label.toLowerCase(),
      _postAnonymously ? 'anonymous' : 'public',
      'exact_road_spot',
    ];

    final payload = TagSubmissionPayload(
      latitude: submitLocation.latitude,
      longitude: submitLocation.longitude,
      category: selected.backendCategory,
      tags: tags,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );

    setState(() => _submitError = null);

    try {
      await ref.read(tagSubmissionProvider.notifier).submit(payload);
    } catch (error) {
      if (!mounted) return;
      final message = _submissionErrorMessage(error);
      setState(() => _submitError = message);
      pushAppNotification(
        ref,
        title: 'Tag not submitted',
        message: message,
        kind: AppNotificationKind.error,
        showBanner: true,
      );
      return;
    }
    if (!mounted) return;

    final focus = LatLng(payload.latitude, payload.longitude);
    final zone = ref.read(selectedZoneProvider) ??
        ref.read(tagFlowZoneOverviewNotifierProvider).overview?.currentZone;
    final summary = _friendlySubmitSummary(zone);

    ref.read(tagSubmittedBannerProvider.notifier).state = TagSubmittedBanner(
      message: summary,
      shownAt: DateTime.now(),
    );
    pushAppNotification(
      ref,
      title: 'Tag submitted',
      message: summary,
      kind: AppNotificationKind.success,
      showToast: true,
      showBanner: true,
    );
    ref.read(tagSubmissionPinLocationProvider.notifier).state = null;
    setState(() {
      _submitError = null;
      _confirmation = _TagSubmitConfirmation(
        focus: focus,
        zone: zone,
        placeTitle: _locationLabel,
        summary: summary,
      );
    });
  }

  String _submissionErrorMessage(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        return 'Please log in again before submitting a tag.';
      }
      if (error.response?.statusCode == 422 ||
          error.response?.statusCode == 429) {
        final limited = error.response?.data;
        if (limited is Map && limited['detail'] != null) {
          return limited['detail'].toString();
        }
        return error.response?.statusCode == 429
            ? 'Too many tags right now. Wait a minute and try again.'
            : 'This tag could not be accepted (duplicate or cooldown).';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return ApiConstants.unreachableMessage();
      }
      final detail = error.response?.data;
      if (detail is Map && detail['detail'] != null) {
        return detail['detail'].toString();
      }
      return 'Submission failed (${error.response?.statusCode ?? 'network'}).';
    }
    return 'Submission failed. Please try again.';
  }

  Future<void> _commitPlaceSearch() async {
    final query = placeSearchController.text.trim();
    if (query.isEmpty) return;
    if (_placeHits.isNotEmpty) {
      _selectPlaceHit(_placeHits.first);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _searchBusy = true);
    final hits = await searchCebuPlaces(ref.read(dioProvider), query);
    if (!mounted) return;
    setState(() {
      _searchBusy = false;
      _placeHits = hits;
      _searchFeedback = hits.isEmpty
          ? 'No places found in Cebu for "$query".'
          : null;
    });
    if (hits.isNotEmpty) _selectPlaceHit(hits.first);
  }

  Future<void> _useGps() async {
    setState(() => _gpsBusy = true);
    final live = await _tagPickerTryCurrentGps();
    if (!mounted) return;
    setState(() => _gpsBusy = false);
    if (live == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not get GPS. Search for a place instead.',
          ),
        ),
      );
      return;
    }
    if (!cebuPlaceWithinServiceArea(live)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS is outside the Cebu tagging area.'),
        ),
      );
      return;
    }
    _ignoreSearch = true;
    placeSearchController.text = 'Current location';
    _ignoreSearch = false;
    _applyLocation(live, label: 'Current location');
  }

  void _useExploreMapCenter() {
    final center = ref.read(mapViewportProvider).center;
    if (!cebuPlaceWithinServiceArea(center)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Explore map center is outside Cebu. Move the map first.'),
        ),
      );
      return;
    }
    _ignoreSearch = true;
    placeSearchController.text = 'Explore map center';
    _ignoreSearch = false;
    _applyLocation(center, label: 'Explore map center');
  }

  String _friendlySubmitSummary(ZoneModel? zone) {
    final where = _locationLabel?.trim().isNotEmpty == true
        ? _locationLabel!.trim()
        : (zone != null ? zoneDisplayTitle(zone) : 'Cebu');
    return '${_selectedType?.label ?? 'Tag'} · $where';
  }

  bool _hasNearbyOwnTag(LatLng location) {
    final reports = ref.read(userContributionsProvider).maybeWhen(
          data: (c) => c?.recentReports ?? const <ReportModel>[],
          orElse: () => const <ReportModel>[],
        );
    for (final report in reports) {
      final lat = report.cellLat;
      final lng = report.cellLng;
      if (lat == null || lng == null) continue;
      if (_approxMeters(location, LatLng(lat, lng)) <= 80) return true;
    }
    return false;
  }

  void _openSubmittedArea() {
    final confirmation = _confirmation;
    if (confirmation == null || _openingSubmittedArea) return;
    _openingSubmittedArea = true;
    _confirmation = null;
    openAreaOnExplore(
      ref,
      context,
      focus: confirmation.focus,
      zone: confirmation.zone,
      title: confirmation.placeTitle ??
          (confirmation.zone == null
              ? null
              : zoneDisplayTitle(confirmation.zone!)),
      submitSummary: confirmation.summary,
    );
  }

  void _addAnotherTag() {
    setState(() {
      _confirmation = null;
      _openingSubmittedArea = false;
      _selectedTypeLabel = null;
      _selectedDetails.clear();
      _noteExpanded = false;
      _submitError = null;
      noteController.clear();
      if (_pickedLocation != null) {
        _locationEditing = false;
        ref.read(tagSubmissionPinLocationProvider.notifier).state =
            _pickedLocation;
      } else {
        _locationEditing = true;
      }
    });
  }

  void _focusLocationPicker() {
    setState(() => _locationEditing = true);
    _scrollTo(_locationKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  String get _actionLabel {
    if (_pickedLocation == null) return 'Choose Location';
    if (_selectedType == null) return 'Choose a category';
    return 'Add Tag';
  }

  @override
  Widget build(BuildContext context) {
    final confirmation = _confirmation;
    if (confirmation != null) {
      return TagSubmittedConfirmationView(
        summary: confirmation.summary,
        onSeeOnMap: _openSubmittedArea,
        onAddAnother: _addAnotherTag,
      );
    }

    final submissionState = ref.watch(tagSubmissionProvider);
    ref.watch(userContributionsProvider);
    final selectedZone = ref.watch(selectedZoneProvider);
    final zoneFlow = ref.watch(tagFlowZoneOverviewNotifierProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final hasLocation = _pickedLocation != null;
    final ZoneModel? zone = hasLocation
        ? zoneFlow.overview?.currentZone
        : (zoneFlow.overview?.currentZone ?? selectedZone);
    final zoneRefreshing = hasLocation && zoneFlow.refreshing;
    final selectedType = _selectedType;
    final nearbyOwnTag =
        hasLocation && _hasNearbyOwnTag(_pickedLocation!);
    final sites = ref.watch(sensitiveSitesProvider).valueOrNull ?? const [];
    final blockedSite = hasLocation
        ? siteContaining(
            sites,
            _pickedLocation!.latitude,
            _pickedLocation!.longitude,
          )
        : null;
    final identityHint = tagsNameFacility(
      [
        ..._selectedDetails,
        if (_selectedTypeLabel != null) _selectedTypeLabel!,
        noteController.text,
      ],
      null,
    );
    final resolvedPlace = _pickedLocation == null
        ? null
        : ref
            .watch(
              resolvedPlaceAtPointProvider((
                lat: _pickedLocation!.latitude,
                lng: _pickedLocation!.longitude,
              )),
            )
            .valueOrNull;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(tagSubmissionPinLocationProvider.notifier).state = null;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF8FAFB),
          foregroundColor: AppColors.primaryText,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              ref.read(tagSubmissionPinLocationProvider.notifier).state = null;
              context.go('/explore');
            },
          ),
          title: const Text(
            'Add a Tag',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
        ),
        body: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              'Help others find useful places around you.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Where is this place?',
              key: _locationKey,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            if (hasLocation && !_locationEditing)
              _SelectedLocationCard(
                title: _locationLabel ?? 'Selected location',
                zone: zone,
                zoneRefreshing: zoneRefreshing,
                placeLine: resolvedPlace == null
                    ? null
                    : '${resolvedPlace.displayName} · ${placeTypeLabel(resolvedPlace.placeType)}',
                onChange: _focusLocationPicker,
              )
            else
              _LocationSearchField(
                controller: placeSearchController,
                focusNode: _searchFocusNode,
                searchBusy: _searchBusy,
                gpsBusy: _gpsBusy,
                hits: _placeHits,
                feedback: _searchFeedback,
                onSubmitted: _commitPlaceSearch,
                onSelectHit: _selectPlaceHit,
                onGps: _useGps,
                onMapCenter: _useExploreMapCenter,
                onClear: () {
                  setState(() {
                    _placeHits = const [];
                    _searchFeedback = null;
                  });
                  placeSearchController.clear();
                },
              ),
            if (hasLocation) ...[
              const SizedBox(height: 10),
              SensitiveSitePreview(pin: _pickedLocation!, sites: sites),
            ],
            if (blockedSite != null) ...[
              const SizedBox(height: 8),
              Text(
                pinOnBuildingCopy(blockedSite.kind),
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ] else if (identityHint) ...[
              const SizedBox(height: 8),
              const Text(
                'This stays a street or cafe tag. It will not name the public place after a nearby station, hospital, or city hall.',
                style: TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
            if (nearbyOwnTag) ...[
              const SizedBox(height: 8),
              const Text(
                'You already tagged near here.',
                style: TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'What are you tagging?',
              key: _categoryKey,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _visibleTypes)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 16),
                    label: Text(type.label),
                    selected: type.label == _selectedTypeLabel,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _selectedTypeLabel = type.label;
                        _selectedDetails.clear();
                      });
                    },
                    selectedColor: type.fill,
                    labelStyle: TextStyle(
                      color: type.label == _selectedTypeLabel
                          ? type.accent
                          : AppColors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ActionChip(
                  label: Text(_showMoreCategories ? 'Less' : 'More'),
                  onPressed: () {
                    setState(() => _showMoreCategories = !_showMoreCategories);
                  },
                ),
              ],
            ),
            if (selectedType != null) ...[
              const SizedBox(height: 16),
              Text(
                selectedType.detailPrompt,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final detail in selectedType.details)
                    FilterChip(
                      label: Text(detail),
                      selected: _selectedDetails.contains(detail),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDetails.add(detail);
                          } else {
                            _selectedDetails.remove(detail);
                          }
                        });
                      },
                      selectedColor: selectedType.fill,
                      checkmarkColor: selectedType.accent,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedDetails.contains(detail)
                            ? selectedType.accent
                            : AppColors.primaryText,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (!_noteExpanded)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _noteExpanded = true),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Anything people should know? (Optional)'),
                ),
              )
            else
              TextField(
                controller: noteController,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'e.g. Affordable street food, best after 6 PM',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _postAnonymously,
              onChanged: (value) => setState(() => _postAnonymously = value),
              title: const Text(
                'Post anonymously',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              subtitle: const Text(
                "Your name won't appear on the tag",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.mutedText,
                ),
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 8),
              Text(
                _submitError!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF991B1B),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: Material(
          color: const Color(0xFFF8FAFB),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12 + (keyboard > 0 ? keyboard : bottom),
            ),
            child: FilledButton.icon(
              onPressed: submissionState.isLoading || blockedSite != null
                  ? null
                  : _submit,
              icon: submissionState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _canSubmit
                          ? Icons.add_location_alt_rounded
                          : Icons.place_outlined,
                    ),
              label: Text(
                submissionState.isLoading
                    ? 'Submitting…'
                    : blockedSite != null
                        ? 'Move the pin'
                        : _actionLabel,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagSubmitConfirmation {
  const _TagSubmitConfirmation({
    required this.focus,
    required this.summary,
    this.zone,
    this.placeTitle,
  });

  final LatLng focus;
  final ZoneModel? zone;
  final String? placeTitle;
  final String summary;
}

class TagSubmittedConfirmationView extends StatelessWidget {
  const TagSubmittedConfirmationView({
    super.key,
    required this.summary,
    required this.onSeeOnMap,
    this.onAddAnother,
  });

  final String summary;
  final VoidCallback onSeeOnMap;
  final VoidCallback? onAddAnother;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onSeeOnMap();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF8FAFB),
          foregroundColor: AppColors.primaryText,
          automaticallyImplyLeading: false,
          title: const Text(
            'Add a Tag',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2F855A),
                  size: 72,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tag submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: AppColors.primaryText,
                    letterSpacing: -0.4,
                  ),
                ),
                if (summary.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF166534),
                    ),
                  ),
                ],
                const Spacer(),
                FilledButton.icon(
                  onPressed: onSeeOnMap,
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('View on Map'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                if (onAddAnother != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onAddAnother,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Add Another Tag'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedLocationCard extends StatelessWidget {
  const _SelectedLocationCard({
    required this.title,
    required this.onChange,
    this.zone,
    this.zoneRefreshing = false,
    this.placeLine,
  });

  final String title;
  final ZoneModel? zone;
  final bool zoneRefreshing;
  final String? placeLine;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final zoneLine = zone == null
        ? (zoneRefreshing ? 'Finding zone…' : null)
        : '${zoneDisplayTitle(zone!)} · ${zoneMapSubtitle(zone!)}';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2F855A)),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (placeLine != null || zoneLine != null)
                    Text(
                      placeLine ?? zoneLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(onPressed: onChange, child: const Text('Change')),
          ],
        ),
      ),
    );
  }
}

class _LocationSearchField extends StatelessWidget {
  const _LocationSearchField({
    required this.controller,
    required this.focusNode,
    required this.searchBusy,
    required this.gpsBusy,
    required this.hits,
    required this.feedback,
    required this.onSubmitted,
    required this.onSelectHit,
    required this.onGps,
    required this.onMapCenter,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searchBusy;
  final bool gpsBusy;
  final List<CebuPlaceSearchHit> hits;
  final String? feedback;
  final Future<void> Function() onSubmitted;
  final void Function(CebuPlaceSearchHit hit) onSelectHit;
  final Future<void> Function() onGps;
  final VoidCallback onMapCenter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            hintText: 'Mall, street, landmark…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (searchBusy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (controller.text.trim().isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onClear,
                  ),
                IconButton(
                  tooltip: 'Use GPS',
                  onPressed: gpsBusy ? null : () => onGps(),
                  icon: gpsBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
                IconButton(
                  tooltip: 'Use Explore map center',
                  onPressed: onMapCenter,
                  icon: const Icon(Icons.map_outlined),
                ),
              ],
            ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (hits.isNotEmpty || feedback != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _TagPlaceSearchResults(
              hits: hits,
              feedback: feedback,
              loading: searchBusy,
              onSelect: onSelectHit,
            ),
          ),
      ],
    );
  }
}

class _TagPlaceSearchResults extends StatelessWidget {
  const _TagPlaceSearchResults({
    required this.hits,
    required this.feedback,
    required this.loading,
    required this.onSelect,
  });

  final List<CebuPlaceSearchHit> hits;
  final String? feedback;
  final bool loading;
  final void Function(CebuPlaceSearchHit hit) onSelect;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty && feedback == null && !loading) {
      return const SizedBox.shrink();
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 4),
        itemCount: hits.isEmpty ? 1 : hits.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (hits.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                loading ? 'Searching Cebu…' : feedback ?? '',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            );
          }
          final hit = hits[index];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.place_outlined,
              size: 20,
              color: AppColors.mutedText,
            ),
            title: Text(
              hit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              hit.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(hit),
          );
        },
      ),
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
    required this.detailPrompt,
    this.primary = false,
  });

  final String backendCategory;
  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
  final List<String> details;
  final String detailPrompt;
  final bool primary;
}
