// ignore_for_file: unused_element, unused_import, unused_field

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/app_providers.dart';
import '../../zones/presentation/zone_detail_sheet.dart';

enum ExploreMapMode { discovery, zoneSelected, navigating }

enum _LocationBootstrapState {
  locating,
  permissionDenied,
  serviceDisabled,
  ready,
}

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  MapLibreMapController? _controller;
  StreamSubscription<Position>? _positionSubscription;
  bool _isUpdatingViewport = false;
  bool _didBootstrapLocation = false;
  bool _didApplyCurrentZone = false;
  bool _isLocationEnabledForMap = false;
  bool _mapStyleLoaded = false;
  bool _zoneLayersAdded = false;
  String? _zoneBelowLayerId;
  List<ZoneModel> _latestZones = const [];
  bool _usingManualLocation = false;
  bool _followUser = true;
  bool _showLayerLegend = false;
  final Set<String> _enabledLayerKeys = {
    'local',
    'international',
    'mixed',
    'commercial',
    'food',
    'transport',
    'school',
    'tourist',
    'safety',
    'hotel',
  };
  _LocationBootstrapState _locationState = _LocationBootstrapState.locating;
  ExploreMapMode _mapMode = ExploreMapMode.discovery;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  static const _cebuCityCenter = LatLng(10.3157, 123.8854);
  static const _defaultZoom = 14.7;
  static const _cebuRegionRadiusMeters = 120000.0;
  static const _zonesSourceId = 'zones-source';
  static const _zonesFillLayerId = 'zones-fill';
  static const _zonesLineLayerId = 'zones-line';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDefaultCebuViewport();
      _bootstrapCurrentLocation();
    });
  }

  Future<void> _bootstrapCurrentLocation({bool force = false}) async {
    if (_didBootstrapLocation && !force) return;
    _didBootstrapLocation = true;
    if (mounted) {
      setState(() => _locationState = _LocationBootstrapState.locating);
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(
            () => _locationState = _LocationBootstrapState.serviceDisabled,
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(
            () => _locationState = _LocationBootstrapState.permissionDenied,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final detectedLocation = LatLng(position.latitude, position.longitude);

      if (!_isWithinCebuRegion(detectedLocation)) {
        setState(() {
          _isLocationEnabledForMap = false;
          _usingManualLocation = false;
          _locationState = _LocationBootstrapState.ready;
        });
        ref.read(currentUserLocationProvider.notifier).state = _cebuCityCenter;
        await _moveCameraToLocation(_cebuCityCenter, zoom: _defaultZoom);
        return;
      }

      setState(() {
        _isLocationEnabledForMap = true;
        _usingManualLocation = false;
        _locationState = _LocationBootstrapState.ready;
      });
      ref.read(currentUserLocationProvider.notifier).state = detectedLocation;
      _startLiveLocationTracking();
      await _moveCameraToLocation(detectedLocation, zoom: 13.5);
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationState = _LocationBootstrapState.serviceDisabled,
        );
      }
    }
  }

  Future<void> _moveCameraToLocation(
    LatLng target, {
    double zoom = _defaultZoom,
  }) async {
    final current = ref.read(mapViewportProvider);
    const latDelta = 0.05;
    const lngDelta = 0.05;
    ref.read(mapViewportProvider.notifier).state = current.copyWith(
      center: target,
      zoom: zoom,
      minLat: target.latitude - latDelta,
      minLng: target.longitude - lngDelta,
      maxLat: target.latitude + latDelta,
      maxLng: target.longitude + lngDelta,
    );
    final controller = _controller;
    if (controller != null) {
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(target, zoom),
      );
    }
  }

  Future<void> _ensureDefaultCebuViewport() async {
    final currentUserLocation = ref.read(currentUserLocationProvider);
    if (currentUserLocation != null &&
        _isWithinCebuRegion(currentUserLocation)) {
      return;
    }
    ref.read(currentUserLocationProvider.notifier).state = _cebuCityCenter;
    await _moveCameraToLocation(_cebuCityCenter, zoom: _defaultZoom);
  }

  bool _isWithinCebuRegion(LatLng location) {
    final distanceMeters = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      _cebuCityCenter.latitude,
      _cebuCityCenter.longitude,
    );
    return distanceMeters <= _cebuRegionRadiusMeters;
  }

  Future<void> _promptManualLocation() async {
    final latController = TextEditingController();
    final lngController = TextEditingController();
    try {
      final result = await showDialog<LatLng>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set location manually'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Latitude'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lngController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Longitude'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final lat = double.tryParse(latController.text.trim());
                final lng = double.tryParse(lngController.text.trim());
                if (lat == null ||
                    lng == null ||
                    lat.abs() > 90 ||
                    lng.abs() > 180) {
                  return;
                }
                Navigator.of(context).pop(LatLng(lat, lng));
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (result == null) return;
      ref.read(currentUserLocationProvider.notifier).state = result;
      _positionSubscription?.cancel();
      if (mounted) {
        setState(() {
          _isLocationEnabledForMap = false;
          _usingManualLocation = true;
          _followUser = false;
          _locationState = _LocationBootstrapState.ready;
        });
      }
      await _moveCameraToLocation(result, zoom: 13.5);
    } finally {
      latController.dispose();
      lngController.dispose();
    }
  }

  Future<void> _drawZones(List<ZoneModel> zones) async {
    final controller = _controller;
    if (controller == null || !_mapStyleLoaded) {
      return;
    }
    _latestZones = zones;
    final selectedZone = ref.read(selectedZoneProvider);
    final userLocation = ref.read(currentUserLocationProvider);
    final mapMode = _mapMode;
    final currentZoom = ref.read(mapViewportProvider).zoom;
    try {
      await controller.clearSymbols();
      await controller.clearCircles();
    } catch (_) {
      return;
    }
    try {
      final features = <Map<String, dynamic>>[];
      for (final zone in zones) {
        final layerKey = _zoneLayerKey(zone);
        final isSelected = selectedZone?.h3Index == zone.h3Index;
        if (!_enabledLayerKeys.contains(layerKey) && !isSelected) continue;
        final color = _streetZoneColor(zone);
        final rings = zone.sourceH3Rings;
        if (rings.isEmpty) continue;
        for (final ring in rings) {
          if (ring.length < 6) continue;
          features.add({
            'type': 'Feature',
            'properties': {
              'zone_id': zone.zoneId,
              'zone_type': layerKey,
              'fill': _hexFromColor(color),
              'line': _hexFromColor(color),
              'selected': isSelected,
            },
            'geometry': {
              'type': 'Polygon',
              'coordinates': [ring],
            },
          });
        }
      }
      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };
      if (!_zoneLayersAdded) {
        await controller.addGeoJsonSource(_zonesSourceId, geoJson);
        final belowLayerId =
            _zoneBelowLayerId ?? await _resolveRoadLayerId(controller);
        _zoneBelowLayerId = belowLayerId;
        await controller.addFillLayer(
          _zonesSourceId,
          _zonesFillLayerId,
          FillLayerProperties(
            fillColor: ['get', 'fill'],
            fillOpacity: [
              'case',
              ['boolean', ['get', 'selected'], false],
              0.33,
              0.28,
            ],
          ),
          belowLayerId: belowLayerId,
        );
        await controller.addLineLayer(
          _zonesSourceId,
          _zonesLineLayerId,
          LineLayerProperties(
            lineColor: ['get', 'line'],
            lineWidth: [
              'case',
              ['boolean', ['get', 'selected'], false],
              1.6,
              1.3,
            ],
            lineOpacity: [
              'case',
              ['boolean', ['get', 'selected'], false],
              0.86,
              0.76,
            ],
          ),
          belowLayerId: belowLayerId,
        );
        _zoneLayersAdded = true;
      } else {
        await controller.setGeoJsonSource(_zonesSourceId, geoJson);
      }

      final labelZones = [...zones]
        ..sort((a, b) {
          final aScore = a.reportCount + a.confidenceScore;
          final bScore = b.reportCount + b.confidenceScore;
          return bScore.compareTo(aScore);
        });
      final labelLimit = currentZoom >= 13
          ? 14
          : currentZoom >= 11.5
          ? 10
          : 6;
      final labeledZoneIds = labelZones
          .take(labelLimit)
          .map((zone) => zone.h3Index)
          .toSet();
      for (final zone in zones) {
        if (zone.polygonParts.isEmpty) {
          continue;
        }
        final isSelected = selectedZone?.h3Index == zone.h3Index;
        final layerKey = _zoneLayerKey(zone);
        final layerVisible = _enabledLayerKeys.contains(layerKey);
        if (!layerVisible && !isSelected) {
          continue;
        }
        final center = _zoneCenter(zone);
        final shouldLabel = mapMode == ExploreMapMode.navigating
            ? isSelected
            : isSelected || labeledZoneIds.contains(zone.h3Index);
        if (shouldLabel) {
          await controller.addSymbol(
            SymbolOptions(
              geometry: center,
              textField: '${_zoneTitle(zone)}\n${_zoneIdentity(zone)}',
              textSize: isSelected
                  ? (currentZoom >= 12.5 ? 13 : 12)
                  : (currentZoom >= 12.5 ? 11.4 : 10.2),
              textColor: isSelected ? '#1F2937' : '#374151',
              textHaloColor: '#FFFFFF',
              textHaloWidth: 1.6,
              textOpacity: isSelected ? 1 : 0.90,
              textAnchor: 'center',
              textMaxWidth: 9,
              zIndex: isSelected ? 4 : 2,
            ),
          );
        }
      }
      if (mapMode == ExploreMapMode.navigating &&
          selectedZone != null &&
          userLocation != null) {
        final target = _zoneCenter(selectedZone);
        await controller.addLine(
          LineOptions(
            geometry: [userLocation, target],
            lineColor: _hexFromColor(AppColors.secondaryAction),
            lineWidth: 4.2,
            lineOpacity: 0.86,
          ),
        );
      }
      if (userLocation != null) {
        await controller.addCircle(
          CircleOptions(
            geometry: userLocation,
            circleRadius: 7.2,
            circleColor: '#2F80ED',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3.0,
          ),
        );
      }
    } catch (_) {
      return;
    }
  }

  Future<String?> _resolveRoadLayerId(MapLibreMapController controller) async {
    try {
      final layers = await controller.getLayerIds();
      const preferredRoadLayers = <String>[
        'road-label',
        'road',
        'roads',
        'transportation',
      ];
      for (final preferred in preferredRoadLayers) {
        for (final raw in layers) {
          final id = raw.toString().toLowerCase();
          if (id == preferred || id.contains(preferred)) return raw.toString();
        }
      }
      for (final raw in layers) {
        final id = raw.toString().toLowerCase();
        if (id.contains('road') || id.contains('street')) return raw.toString();
      }
      for (final raw in layers) {
        final id = raw.toString().toLowerCase();
        if (id.contains('label')) return raw.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _applyBaseMapVisualTuning(MapLibreMapController controller) async {
    try {
      final layers = await controller.getLayerIds();
      for (final raw in layers) {
        final layerId = raw.toString();
        final id = layerId.toLowerCase();
        if (id.contains('poi') ||
            id.contains('medical') ||
            id.contains('hospital') ||
            id.contains('clinic') ||
            id.contains('pharmacy')) {
          try {
            await controller.setLayerProperties(
              layerId,
              SymbolLayerProperties(
                iconOpacity: 0,
                textOpacity: 0,
              ),
            );
          } catch (_) {}
        } else if (id.contains('transit') ||
            id.contains('rail') ||
            id.contains('station')) {
          try {
            await controller.setLayerProperties(
              layerId,
              LineLayerProperties(lineOpacity: 0.2),
            );
          } catch (_) {
            try {
              await controller.setLayerProperties(
                layerId,
                SymbolLayerProperties(iconOpacity: 0.3, textOpacity: 0.3),
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  LatLng _zoneCenter(ZoneModel zone) {
    // Prefer the backend-computed centroid — it accounts for multi-part
    // zones and holes correctly. Fall back to the first outer ring's
    // average only if the centroid is missing.
    if (zone.centroidLat != 0.0 || zone.centroidLng != 0.0) {
      return LatLng(zone.centroidLat, zone.centroidLng);
    }
    if (zone.boundary.isEmpty) {
      return const LatLng(0, 0);
    }
    final lng =
        zone.boundary.map((point) => point[0]).reduce((a, b) => a + b) /
        zone.boundary.length;
    final lat =
        zone.boundary.map((point) => point[1]).reduce((a, b) => a + b) /
        zone.boundary.length;
    return LatLng(lat, lng);
  }

  ZoneModel? _findNearestZone(LatLng tap, List<ZoneModel> zones) {
    ZoneModel? selected;
    var bestDistance = double.infinity;
    for (final zone in zones) {
      final center = _zoneCenter(zone);
      final distance =
          (tap.latitude - center.latitude) * (tap.latitude - center.latitude) +
          (tap.longitude - center.longitude) *
              (tap.longitude - center.longitude);
      if (distance < bestDistance) {
        bestDistance = distance;
        selected = zone;
      }
    }
    return selected;
  }

  Future<void> _refreshViewportZones() async {
    final controller = _controller;
    if (controller == null || _isUpdatingViewport) {
      return;
    }
    _isUpdatingViewport = true;
    try {
      final bounds = await controller.getVisibleRegion();
      final camera = controller.cameraPosition;
      final current = ref.read(mapViewportProvider);
      ref.read(mapViewportProvider.notifier).state = current.copyWith(
        center: camera?.target,
        zoom: camera?.zoom,
        minLat: bounds.southwest.latitude,
        minLng: bounds.southwest.longitude,
        maxLat: bounds.northeast.latitude,
        maxLng: bounds.northeast.longitude,
      );
      final zones = ref.read(visibleZonesProvider).valueOrNull;
      if (zones != null) {
        unawaited(_drawZones(zones));
      }
    } finally {
      _isUpdatingViewport = false;
    }
  }

  void _selectZone(ZoneModel zone) {
    ref.read(selectedZoneProvider.notifier).state = zone;
    setState(() => _mapMode = ExploreMapMode.zoneSelected);
  }

  void _clearSelectedZone() {
    ref.read(selectedZoneProvider.notifier).state = null;
    setState(() => _mapMode = ExploreMapMode.discovery);
  }

  void _startNavigation(ZoneModel zone) {
    ref.read(selectedZoneProvider.notifier).state = zone;
    setState(() {
      _mapMode = ExploreMapMode.navigating;
      _followUser = true;
    });
    final target = _zoneCenter(zone);
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.animateCamera(CameraUpdate.newLatLngZoom(target, 13.2)));
    }
  }

  void _exitNavigation() {
    setState(() {
      _mapMode = ref.read(selectedZoneProvider) == null
          ? ExploreMapMode.discovery
          : ExploreMapMode.zoneSelected;
      _followUser = false;
    });
  }

  void _startLiveLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 12,
          ),
        ).listen((position) async {
          if (!mounted || _usingManualLocation) return;
          final live = LatLng(position.latitude, position.longitude);
          ref.read(currentUserLocationProvider.notifier).state = live;
          if (_followUser) {
            final controller = _controller;
            if (controller != null) {
              await controller.moveCamera(
                CameraUpdate.newLatLngZoom(
                  live,
                  _mapMode == ExploreMapMode.navigating ? 14 : 13,
                ),
              );
            }
          }
        });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
      }
    });
    if (!_showSearch) {
      ref.read(activeZoneFilterProvider.notifier).state = null;
    }
  }

  void _applySearchFilter(String value) {
    final q = value.trim().toLowerCase();
    if (q.isEmpty) {
      ref.read(activeZoneFilterProvider.notifier).state = null;
      return;
    }
    if (q.contains('food')) {
      ref.read(activeZoneFilterProvider.notifier).state = 'food';
      return;
    }
    if (q.contains('local')) {
      ref.read(activeZoneFilterProvider.notifier).state = 'local_picks';
      return;
    }
    if (q.contains('tour') || q.contains('international')) {
      ref.read(activeZoneFilterProvider.notifier).state = 'tourist';
      return;
    }
    if (q.contains('popular') || q.contains('trend')) {
      ref.read(activeZoneFilterProvider.notifier).state = 'popular_now';
      return;
    }
    ref.read(activeZoneFilterProvider.notifier).state = null;
  }

  void _applyTopTagFilter(String? filterKey) {
    ref.read(activeZoneFilterProvider.notifier).state = filterKey;
  }

  void _toggleLayerKey(String key) {
    setState(() {
      if (_enabledLayerKeys.contains(key)) {
        if (_enabledLayerKeys.length > 1) {
          _enabledLayerKeys.remove(key);
        }
      } else {
        _enabledLayerKeys.add(key);
      }
    });
  }

  List<fm.Polygon<Object>> _buildStreetZoomPolygons(
    List<ZoneModel> zones,
    ZoneModel? selectedZone,
    double zoom,
  ) {
    return zones
        .where((zone) {
          final layerKey = _zoneLayerKey(zone);
          return _enabledLayerKeys.contains(layerKey) ||
              selectedZone?.h3Index == zone.h3Index;
        })
        .expand((zone) {
          final color = _streetZoneColor(zone);
          final selected = selectedZone?.h3Index == zone.h3Index;
          final opacity = selected ? 0.30 : (zoom >= 14.2 ? 0.24 : 0.18);
          final hexRings = zone.sourceH3Rings;
          if (hexRings.isNotEmpty) {
            return hexRings.map((ring) {
              final points = ring.map((point) => ll.LatLng(point[1], point[0])).toList();
              return fm.Polygon(
                points: points,
                // Outline-only zones so roads remain completely plain.
                color: Colors.transparent,
                borderColor: color.withValues(alpha: selected ? 0.82 : 0.68),
                borderStrokeWidth: selected ? 1.25 : 1.0,
              );
            });
          }
          return zone.polygonParts.expand((rings) {
            if (rings.isEmpty) return const <fm.Polygon<Object>>[];
            final outerRing = rings.first
                .map((point) => ll.LatLng(point[1], point[0]))
                .toList();
            if (outerRing.length < 3) return const <fm.Polygon<Object>>[];
            return [
              fm.Polygon(
                points: outerRing,
                color: color.withValues(alpha: opacity),
                borderColor: color.withValues(alpha: selected ? 0.80 : 0.66),
                borderStrokeWidth: selected ? 1.45 : 1.2,
              ),
            ];
          });
        })
        .toList();
  }

  List<fm.Marker> _buildStreetZoomLabels(
    List<ZoneModel> zones,
    ZoneModel? selectedZone,
    double zoom,
  ) {
    if (zoom < 13.4) {
      return const <fm.Marker>[];
    }
    final limit = zoom >= 15 ? 7 : 4;
    final sorted = [...zones]
      ..sort(
        (a, b) => (b.reportCount + b.confidenceScore).compareTo(
          a.reportCount + a.confidenceScore,
        ),
      );
    final visibleIds = sorted.take(limit).map((z) => z.h3Index).toSet();
    return zones
        .where((zone) {
          final layerKey = _zoneLayerKey(zone);
          final selected = selectedZone?.h3Index == zone.h3Index;
          return (_enabledLayerKeys.contains(layerKey) &&
                  visibleIds.contains(zone.h3Index)) ||
              selected;
        })
        .map((zone) {
          final color = _streetZoneColor(zone);
          return fm.Marker(
            point: ll.LatLng(
              _zoneCenter(zone).latitude,
              _zoneCenter(zone).longitude,
            ),
            width: 170,
            height: 74,
            child: GestureDetector(
              onTap: () => _selectZone(zone),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_zoneIcon(zone), color: color, size: 17),
                  Text(
                    _zoneTitle(zone),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _darken(color, 0.18),
                      fontWeight: FontWeight.w800,
                      fontSize: zoom >= 15 ? 14 : 13,
                    ),
                  ),
                  Text(
                    _zoneIdentity(zone),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _darken(color, 0.12).withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        })
        .toList();
  }

  Color _streetZoneColor(ZoneModel zone) {
    return switch (_zoneLayerKey(zone)) {
      'local' => const Color(0xFF5FAF7A),
      'commercial' => const Color(0xFFE96F7D),
      'food' => const Color(0xFFEFA15C),
      'transport' => const Color(0xFFE4BF38),
      'school' => const Color(0xFF8B6FE8),
      'tourist' => const Color(0xFF57B6C2),
      'hotel' => const Color(0xFFE592B8),
      'safety' => const Color(0xFFEF5350),
      'international' => const Color(0xFF57B6C2),
      _ => const Color(0xFF8B6FE8),
    };
  }

  @override
  Widget build(BuildContext context) {
    final zonesValue = ref.watch(visibleZonesProvider);
    final selectedZone = ref.watch(selectedZoneProvider);
    final currentUserLocation = ref.watch(currentUserLocationProvider);
    final currentZoneOverview = ref.watch(currentZoneOverviewProvider);
    currentZoneOverview.whenData((overview) {
      if (_didApplyCurrentZone || overview?.currentZone == null) return;
      _didApplyCurrentZone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedZoneProvider.notifier).state = overview!.currentZone;
      });
    });
    zonesValue.whenData((zones) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_drawZones(zones));
      });
    });

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return Stack(
            children: [
              MapLibreMap(
                styleString:
                    'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
                initialCameraPosition: const CameraPosition(
                  target: _cebuCityCenter,
                  zoom: 14.7,
                ),
                minMaxZoomPreference: const MinMaxZoomPreference(7.8, 18),
                rotateGesturesEnabled: false,
                onMapCreated: (controller) {
                  _controller = controller;
                },
                onStyleLoadedCallback: () async {
                  _mapStyleLoaded = true;
                  _zoneLayersAdded = false;
                  final controller = _controller;
                  if (controller == null) return;
                  await _applyBaseMapVisualTuning(controller);
                  _zoneBelowLayerId = await _resolveRoadLayerId(controller);
                  final zones = ref.read(visibleZonesProvider).valueOrNull;
                  if (zones != null) {
                    unawaited(_drawZones(zones));
                  }
                },
                onCameraIdle: _refreshViewportZones,
                onMapClick: (point, latLng) {
                  if (_mapMode == ExploreMapMode.navigating) return;
                  final zones = _latestZones;
                  if (zones.isEmpty) return;
                  final selected = _findNearestZone(
                    LatLng(latLng.latitude, latLng.longitude),
                    zones,
                  );
                  if (selected != null) _selectZone(selected);
                },
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.38),
                        Colors.white.withValues(alpha: 0.07),
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.04),
                      ],
                      stops: const [0, 0.10, 0.45, 1],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              if (_mapMode == ExploreMapMode.navigating)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _RoutePreviewPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapTopBar(
                      zoneCount: zonesValue.maybeWhen(
                        data: (zones) => zones.length,
                        orElse: () => null,
                      ),
                      onSearchTap: _toggleSearch,
                      onNotificationTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _LocationStatusBanner(
                      state: _locationState,
                      usingManualLocation: _usingManualLocation,
                      importantZoneIssue: currentZoneOverview.asData?.value
                          ?.currentZone
                          ?.liveStatus,
                      onRetry: () => _bootstrapCurrentLocation(force: true),
                      onManualLocation: _promptManualLocation,
                    ),
                    const SizedBox(height: 8),
                    _TopTagFilterRow(onTagSelected: _applyTopTagFilter),
                    if (_showSearch) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x100F172A),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _applySearchFilter,
                            decoration: InputDecoration(
                              hintText: 'Search Cebu (IT Park food...)',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.primaryText,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.mutedText,
                                ),
                                onPressed: _toggleSearch,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 18,
                bottom: selectedZone != null ? (compact ? 242 : 264) : 152,
                child: Column(
                  children: [
                    if (_mapMode == ExploreMapMode.navigating)
                      _MapFab(
                        heroTag: 'exit-nav-btn',
                        icon: Icons.close_rounded,
                        onPressed: _exitNavigation,
                      )
                    else
                      Column(
                        children: [
                          _MapFab(
                            heroTag: 'location-btn',
                            icon: _followUser
                                ? Icons.my_location_rounded
                                : Icons.location_searching_rounded,
                            onPressed: () {
                              if (_usingManualLocation) {
                                _promptManualLocation();
                              } else {
                                setState(() => _followUser = true);
                                _bootstrapCurrentLocation(force: true);
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          _MapFab(
                            heroTag: 'layers-btn',
                            icon: Icons.tune_rounded,
                            onPressed: () {
                              setState(
                                () => _showLayerLegend = !_showLayerLegend,
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (_mapMode != ExploreMapMode.navigating)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: selectedZone != null
                      ? (compact ? 298 : 318)
                      : (compact ? 28 : 34),
                  child: const SizedBox.shrink(),
                ),
              if (selectedZone != null || _mapMode == ExploreMapMode.navigating)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18,
                  child: zonesValue.when(
                    data: (zones) {
                      if (zones.isEmpty) {
                        return const _LoadingZoneCard(message: 'No zones here');
                      }
                      final previewZone = selectedZone ?? zones.first;
                      if (_mapMode == ExploreMapMode.navigating) {
                        return _NavigationCard(
                          zone: previewZone,
                          metrics: _buildNavigationMetrics(
                            userLocation: currentUserLocation,
                            targetZone: previewZone,
                          ),
                          followUser: _followUser,
                          onToggleFollow: () {
                            setState(() => _followUser = !_followUser);
                          },
                          onExit: _exitNavigation,
                          onDetails: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.black.withValues(alpha: 0.35),
                            builder: (_) => const ZoneDetailSheet(),
                          ),
                        );
                      }
                      return _SelectedZoneCard(
                        zone: previewZone,
                        onClose: _clearSelectedZone,
                        onDirections: () => _startNavigation(previewZone),
                        onDetails: () {
                          _selectZone(previewZone);
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.black.withValues(alpha: 0.35),
                            builder: (_) => const ZoneDetailSheet(),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const _LoadingZoneCard(message: 'Loading zones...'),
                    error: (error, _) => _LoadingZoneCard(
                      message: 'Unable to load zones: ${_shortError(error)}',
                    ),
                  ),
                ),
              Positioned(
                right: 18,
                bottom: selectedZone != null ? (compact ? 358 : 386) : 254,
                child: AnimatedOpacity(
                  opacity: _showLayerLegend ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_showLayerLegend,
                    child: _ZoneLegendPanel(
                      expanded: true,
                      enabledKeys: _enabledLayerKeys,
                      onToggleExpanded: () {
                        setState(() => _showLayerLegend = false);
                      },
                      onToggleLayer: _toggleLayerKey,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

_NavigationMetrics _buildNavigationMetrics({
  required LatLng? userLocation,
  required ZoneModel targetZone,
}) {
  if (userLocation == null) {
    return const _NavigationMetrics(
      distanceText: 'Locating...',
      etaText: '--',
      nextStep: 'Getting your live location',
    );
  }
  final target = LatLng(targetZone.centroidLat, targetZone.centroidLng);
  final meters = Geolocator.distanceBetween(
    userLocation.latitude,
    userLocation.longitude,
    target.latitude,
    target.longitude,
  );
  final distanceText = meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';
  final etaMinutes = (meters / 78).ceil().clamp(1, 120);
  final heading = _directionFromBearing(
    _bearingDegrees(
      userLocation.latitude,
      userLocation.longitude,
      target.latitude,
      target.longitude,
    ),
  );
  return _NavigationMetrics(
    distanceText: distanceText,
    etaText: '$etaMinutes min',
    nextStep: 'Head $heading toward ${_zoneTitle(targetZone)}',
  );
}

double _bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
  final dLon = (lon2 - lon1) * 0.017453292519943295;
  final rLat1 = lat1 * 0.017453292519943295;
  final rLat2 = lat2 * 0.017453292519943295;
  final y = math.sin(dLon) * math.cos(rLat2);
  final x =
      math.cos(rLat1) * math.sin(rLat2) -
      math.sin(rLat1) * math.cos(rLat2) * math.cos(dLon);
  final brng = math.atan2(y, x) * 57.29577951308232;
  return (brng + 360) % 360;
}

String _directionFromBearing(double bearing) {
  if (bearing < 22.5 || bearing >= 337.5) return 'north';
  if (bearing < 67.5) return 'north-east';
  if (bearing < 112.5) return 'east';
  if (bearing < 157.5) return 'south-east';
  if (bearing < 202.5) return 'south';
  if (bearing < 247.5) return 'south-west';
  if (bearing < 292.5) return 'west';
  return 'north-west';
}

String _shortError(Object error) {
  final msg = error.toString();
  if (msg.length <= 80) return msg;
  return '${msg.substring(0, 77)}...';
}

String _zoneTitle(ZoneModel zone) {
  // Prefer the landmark portion of the backend's display name
  // ("Food Hotspot near Colon Street" -> "Colon Street").
  final name = zone.displayName.trim();
  if (name.isNotEmpty) {
    final nearIdx = name.toLowerCase().lastIndexOf(' near ');
    if (nearIdx >= 0 && nearIdx + 6 < name.length) {
      return name.substring(nearIdx + 6).trim();
    }
    return name;
  }
  // Fallback when the API didn't set a display name.
  final traveler = zone.travelerType.toLowerCase();
  final type = zone.zoneType.toLowerCase();
  if (type.contains('food')) return 'Colon Street';
  if (type.contains('transport')) return 'Port Area';
  if (type.contains('school')) return 'University Zone';
  if (type.contains('tourist')) return 'IT Park';
  if (type.contains('commercial')) return 'Ayala Center';
  if (type.contains('residential')) return 'Lahug';
  if (type.contains('safety')) return 'Alert Area';
  if (traveler.contains('local')) return 'Lahug';
  if (traveler.contains('international')) return 'IT Park';
  return 'Ayala Center';
}

double _zoneFillOpacity({
  required ExploreMapMode mode,
  required bool selected,
  required bool hasSelection,
  required double confidenceScore,
}) {
  if (mode == ExploreMapMode.navigating) {
    return selected ? 0.20 : 0.18;
  }
  if (selected) {
    return 0.30;
  }
  if (hasSelection) {
    return 0.18;
  }
  if (confidenceScore >= 70) {
    return 0.30;
  }
  if (confidenceScore >= 45) {
    return 0.24;
  }
  return 0.18;
}

String _zoneLayerKey(ZoneModel zone) {
  final type = zone.zoneType.toLowerCase();
  if (type.contains('food')) return 'food';
  if (type.contains('transport')) return 'transport';
  if (type.contains('school') || type.contains('student')) return 'school';
  if (type.contains('safety') || type.contains('issue')) return 'safety';
  if (type.contains('hotel')) return 'hotel';
  if (type.contains('tourist')) return 'tourist';
  if (type.contains('commercial')) return 'commercial';
  if (zone.travelerType == 'Local') return 'local';
  if (zone.travelerType == 'International') return 'international';
  return 'mixed';
}

String _zoneSubtitle(ZoneModel zone) {
  if (zone.reportCount >= 45) return 'Busy now';
  if (zone.confidenceScore >= 70) return 'Popular';
  if (zone.travelerType == 'Local') return 'Mostly locals';
  if (zone.travelerType == 'International') return 'Popular with tourists';
  return 'Balanced city activity';
}

String _zoneIdentity(ZoneModel zone) {
  final type = zone.zoneType.toLowerCase();
  if (type.contains('food')) return 'Food Hotspot';
  if (type.contains('transport')) return 'Transport Zone';
  if (type.contains('school')) return 'Student Area';
  if (type.contains('commercial')) return 'Commercial Zone';
  if (type.contains('residential')) return 'Local Area';
  if (type.contains('safety')) return 'Safety Concern';
  if (type.contains('tourist')) return 'Tourist Area';
  return switch (zone.travelerType) {
    'Local' => 'Local Area',
    'International' => 'Tourist Area',
    _ => 'Mixed Area',
  };
}

String _zoneSummary(ZoneModel zone) {
  final identity = _zoneIdentity(zone);
  if (identity == 'Food Hotspot') {
    return 'Affordable food, busy streets, easy stops';
  }
  if (identity == 'Transport Zone') {
    return 'Good access, high movement, watch peak hours';
  }
  if (identity == 'Student Area') {
    return 'Students, cafes, budget-friendly places';
  }
  if (identity == 'Commercial Zone') {
    return 'Cafes, offices, shopping, night activity';
  }
  if (identity == 'Local Area') {
    return 'Mostly locals, relaxed pace, useful nearby stops';
  }
  if (identity == 'Tourist Area') {
    return 'High activity, safe, many places to explore';
  }
  if (identity == 'Safety Concern') {
    return 'Recent reports suggest extra awareness here';
  }
  return 'Balanced mix of locals and visitors';
}

String _hexFromColor(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color _darken(Color color, [double amount = 0.25]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
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
  if (type.contains('hotel')) {
    return const _ZonePalette(
      fill: AppColors.hotelFill,
      border: AppColors.zoneCommercial,
      accent: AppColors.hotelAccent,
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
      accent: AppColors.secondaryText,
    );
  }
  if (type.contains('safety') || type.contains('issue')) {
    return const _ZonePalette(
      fill: AppColors.safetyFill,
      border: AppColors.safetyBorder,
      accent: AppColors.safetyAccent,
    );
  }
  return switch (zone.travelerType) {
    'Local' => const _ZonePalette(
      fill: AppColors.localFill,
      border: AppColors.travelerLocal,
      accent: AppColors.localAccent,
    ),
    'International' => const _ZonePalette(
      fill: AppColors.touristFill,
      border: AppColors.travelerInternational,
      accent: AppColors.touristAccent,
    ),
    _ => const _ZonePalette(
      fill: AppColors.mixedFill,
      border: AppColors.travelerMixed,
      accent: AppColors.mixedAccent,
    ),
  };
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

class _LocationStatusBanner extends StatelessWidget {
  const _LocationStatusBanner({
    required this.state,
    required this.usingManualLocation,
    required this.importantZoneIssue,
    required this.onRetry,
    required this.onManualLocation,
  });

  final _LocationBootstrapState state;
  final bool usingManualLocation;
  final String? importantZoneIssue;
  final VoidCallback onRetry;
  final VoidCallback onManualLocation;

  @override
  Widget build(BuildContext context) {
    final showZoneIssue = importantZoneIssue == 'caution_now' ||
        importantZoneIssue == 'peak_now';
    if (state == _LocationBootstrapState.ready &&
        !usingManualLocation &&
        !showZoneIssue) {
      return const SizedBox.shrink();
    }
    final (icon, message, action) = switch (state) {
      _LocationBootstrapState.ready when showZoneIssue => (
        Icons.warning_amber_rounded,
        importantZoneIssue == 'caution_now'
            ? 'Safety warning reported in your current zone.'
            : 'Current zone is at peak crowd level.',
        null,
      ),
      _LocationBootstrapState.ready => (
        Icons.edit_location_alt_rounded,
        'Using your manual location. You can change it anytime.',
        null,
      ),
      _LocationBootstrapState.locating => (
        Icons.gps_fixed_rounded,
        'Detecting your location...',
        null,
      ),
      _LocationBootstrapState.permissionDenied => (
        Icons.location_disabled_rounded,
        "Location Access 'Always' needed. Go to Settings to fix it.",
        'Open settings',
      ),
      _LocationBootstrapState.serviceDisabled => (
        Icons.location_off_rounded,
        'Location services are off. Turn on GPS for live zone context.',
        'Retry',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: showZoneIssue
              ? AppColors.safetyFill.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: showZoneIssue ? AppColors.safetyBorder : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: showZoneIssue ? AppColors.safetyAccent : AppColors.mutedText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (action != null) ...[
              TextButton(
                onPressed: state == _LocationBootstrapState.permissionDenied
                    ? Geolocator.openAppSettings
                    : onRetry,
                child: Text(
                  action,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
            if (state == _LocationBootstrapState.ready && usingManualLocation)
              TextButton(
                onPressed: onManualLocation,
                child: const Text(
                  'Change',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
    required this.zoneCount,
    required this.onSearchTap,
    required this.onNotificationTap,
  });

  final int? zoneCount;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'lib/app/theme/strollwiselogo.jpg',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onSearchTap,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      zoneCount == null
                          ? 'Search places or zones...'
                          : 'Search $zoneCount zones',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _TopIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: onNotificationTap,
            showDot: true,
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(icon, color: const Color(0xFF111827), size: 22),
              ),
              if (showDot)
                Positioned(
                  top: 11,
                  right: 11,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTagFilterRow extends ConsumerWidget {
  const _TopTagFilterRow({required this.onTagSelected});

  final ValueChanged<String?> onTagSelected;

  static const _tags =
      <
        ({String label, String? filter, IconData icon, Color color, Color fill})
      >[
        (
          label: 'Local',
          filter: 'local_picks',
          icon: Icons.groups_rounded,
          color: AppColors.localAccent,
          fill: AppColors.localFill,
        ),
        (
          label: 'International',
          filter: 'tourist',
          icon: Icons.flight_takeoff_rounded,
          color: AppColors.touristAccent,
          fill: AppColors.touristFill,
        ),
        (
          label: 'Mixed Zone',
          filter: null,
          icon: Icons.hub_outlined,
          color: AppColors.mixedAccent,
          fill: AppColors.mixedFill,
        ),
        (
          label: 'Commercial',
          filter: 'commercial',
          icon: Icons.business_outlined,
          color: AppColors.commercialAccent,
          fill: AppColors.commercialFill,
        ),
        (
          label: 'Food Hotspot',
          filter: 'food',
          icon: Icons.restaurant_rounded,
          color: AppColors.foodAccent,
          fill: AppColors.foodFill,
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(activeZoneFilterProvider);
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final tag = _tags[index];
          final selected =
              activeFilter == tag.filter ||
              (tag.filter == null &&
                  activeFilter != 'local_picks' &&
                  activeFilter != 'tourist' &&
                  activeFilter != 'commercial' &&
                  activeFilter != 'food');
          return Material(
            color: selected
                ? tag.fill.withValues(alpha: 0.50)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onTagSelected(tag.filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? tag.color.withValues(alpha: 0.95)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      tag.icon,
                      size: 14,
                      color: selected ? tag.color : AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tag.label,
                      style: TextStyle(
                        color: selected ? tag.color : AppColors.primaryText,
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: _tags.length,
      ),
    );
  }
}

class _SearchFilterRow extends StatelessWidget {
  const _SearchFilterRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F172A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search Cebu (IT Park, Ayala...)',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryText,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.primaryText),
                SizedBox(width: 8),
                Text(
                  'Filters',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single filter option surfaced in the explore screen's chip rows.
///
/// [filterKey] is the value we send to the backend as `?filter=`. `null`
/// means "no filter" (the default server ordering by `priority_score`).
/// Keys here must match [RankingService.FILTERS] in the backend.
///
/// [accent] is the colour used to tint the chip when it's selected and is
/// the same colour the matching zone uses on the map — so the chip row
/// doubles as a legend.
class _ExploreFilter {
  const _ExploreFilter({
    required this.label,
    required this.icon,
    required this.filterKey,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final String? filterKey;
  final Color accent;
}

// Keep this list in sync with backend/app/services/ranking_service.py.
// Each chip's accent matches the zone colour rendered on the map so the
// chip row doubles as the legend — there is no separate legend card.
const List<_ExploreFilter> _exploreFilters = [
  _ExploreFilter(
    label: 'For You',
    icon: Icons.star_rounded,
    filterKey: null,
    accent: AppColors.primaryAction,
  ),
  _ExploreFilter(
    label: 'Popular',
    icon: Icons.local_fire_department_rounded,
    filterKey: 'popular_now',
    accent: AppColors.busyAccent,
  ),
  _ExploreFilter(
    label: 'Local Picks',
    icon: Icons.groups_rounded,
    filterKey: 'local_picks',
    accent: AppColors.travelerLocal,
  ),
  _ExploreFilter(
    label: 'Tourist',
    icon: Icons.flight_takeoff_rounded,
    filterKey: 'tourist',
    accent: AppColors.travelerInternational,
  ),
  _ExploreFilter(
    label: 'Food',
    icon: Icons.restaurant_rounded,
    filterKey: 'food',
    accent: AppColors.zoneFood,
  ),
  _ExploreFilter(
    label: 'Transport',
    icon: Icons.directions_bus_rounded,
    filterKey: 'transport',
    accent: AppColors.zoneTransport,
  ),
  _ExploreFilter(
    label: 'Commercial',
    icon: Icons.shopping_bag_rounded,
    filterKey: 'commercial',
    accent: AppColors.zoneCommercial,
  ),
];

_ExploreFilter _activeFilter(String? key) {
  for (final f in _exploreFilters) {
    if (f.filterKey == key) return f;
  }
  return _exploreFilters.first;
}

class _RecommendedPill extends ConsumerWidget {
  const _RecommendedPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeKey = ref.watch(activeZoneFilterProvider);
    final filter = _activeFilter(activeKey);
    final isFiltered = activeKey != null;
    final label = isFiltered
        ? 'Showing: ${filter.label}'
        : 'Showing: Recommended';
    final accent = isFiltered ? filter.accent : AppColors.mapInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isFiltered
            ? accent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isFiltered ? accent : AppColors.border,
          width: isFiltered ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered ? filter.icon : Icons.auto_awesome_rounded,
            size: 15,
            color: accent,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  ref.read(activeZoneFilterProvider.notifier).state = null,
              child: Icon(Icons.close_rounded, size: 14, color: accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileExploreChips extends ConsumerWidget {
  const _MobileExploreChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeZoneFilterProvider);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: _exploreFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _exploreFilters[index];
          final isSelected = filter.filterKey == active;
          return _ExploreChip(
            icon: filter.icon,
            label: filter.label,
            accent: filter.accent,
            selected: isSelected,
            onTap: () {
              // Tapping the active chip (other than "For You") clears
              // the filter and returns to the default ranking.
              ref
                  .read(activeZoneFilterProvider.notifier)
                  .state = isSelected && filter.filterKey != null
                  ? null
                  : filter.filterKey;
            },
          );
        },
      ),
    );
  }
}

class _ExplorePanel extends ConsumerWidget {
  const _ExplorePanel({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeZoneFilterProvider);

    Widget buildChip(_ExploreFilter filter) {
      final isSelected = filter.filterKey == active;
      return _ExploreChip(
        icon: filter.icon,
        label: filter.label,
        accent: filter.accent,
        selected: isSelected,
        onTap: () {
          ref.read(activeZoneFilterProvider.notifier).state =
              isSelected && filter.filterKey != null ? null : filter.filterKey;
        },
      );
    }

    return Container(
      width: 226,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore by',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < _exploreFilters.length; i++) ...[
            buildChip(_exploreFilters[i]),
            if (i != _exploreFilters.length - 1) const SizedBox(height: 7),
          ],
          const Divider(height: 22),
          const _ZoneToggle(
            label: 'Local Zone',
            color: AppColors.travelerLocal,
          ),
          const _ZoneToggle(
            label: 'International',
            color: AppColors.travelerInternational,
          ),
          const _ZoneToggle(
            label: 'Mixed Zone',
            color: AppColors.travelerMixed,
          ),
          const _ZoneToggle(label: 'Food Zone', color: AppColors.zoneFood),
          const _ZoneToggle(label: 'Transport', color: AppColors.zoneTransport),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () {
                ref.read(activeZoneFilterProvider.notifier).state = null;
                onClear();
              },
              child: const Text('Clear All'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreChip extends StatelessWidget {
  const _ExploreChip({
    required this.icon,
    required this.label,
    required this.accent,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Unselected chips still hint at the zone colour via a coloured dot
    // and tinted icon, so the row reads as a legend even when no filter
    // is active. Selected chips get a full accent tint + border.
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? accent : AppColors.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primaryText : AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: content,
      ),
    );
  }
}

class _ZoneToggle extends StatelessWidget {
  const _ZoneToggle({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(
            Icons.check_box_rounded,
            color: Color(0xFF16A34A),
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _SelectedZoneCard extends StatelessWidget {
  const _SelectedZoneCard({
    required this.zone,
    required this.onDetails,
    required this.onDirections,
    required this.onClose,
  });

  final ZoneModel zone;
  final VoidCallback onDetails;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = _zonePalette(zone);
    return GestureDetector(
      onTap: onDetails,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: palette.border.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x260F172A),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ZoneIconBadge(palette: palette, zone: zone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _zoneTitle(zone),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: palette.fill,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _zoneIdentity(zone),
                              style: TextStyle(
                                color: palette.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _zoneSummary(zone),
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Live update: ${_zoneSubtitle(zone)}',
                        style: TextStyle(
                          color: palette.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dismiss the selected-zone card and return to the
                // clean map + Live City Pulse state.
                _CloseButton(onPressed: onClose),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MetricCell(
                  icon: Icons.bar_chart_rounded,
                  label: 'Activity',
                  value: zone.reportCount >= 35 ? 'Busy' : 'Moderate',
                  accent: AppColors.accent,
                ),
                _MetricCell(
                  icon: Icons.groups_rounded,
                  label: 'Local presence',
                  value: _localPresence(zone),
                ),
                _MetricCell(
                  icon: Icons.verified_user_outlined,
                  label: 'Best time',
                  value: '4PM-9PM',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onDetails,
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: const Text('Directions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // GestureDetector with opaque behavior prevents the surrounding
    // card's onTap (which opens the detail sheet) from firing.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 18,
          color: AppColors.primaryText,
        ),
      ),
    );
  }
}

String _localPresence(ZoneModel zone) {
  if (zone.travelerType == 'Local') return '72%';
  if (zone.travelerType == 'International') return '38%';
  return '55%';
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.zone,
    required this.metrics,
    required this.followUser,
    required this.onToggleFollow,
    required this.onExit,
    required this.onDetails,
  });

  final ZoneModel zone;
  final _NavigationMetrics metrics;
  final bool followUser;
  final VoidCallback onToggleFollow;
  final VoidCallback onExit;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final palette = _zonePalette(zone);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryAction,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Navigating to ${_zoneTitle(zone)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_zoneIdentity(zone)} • zones faded for route clarity',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${metrics.distanceText} • ${metrics.etaText}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  metrics.nextStep,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: followUser ? 'Disable follow mode' : 'Enable follow mode',
            onPressed: onToggleFollow,
            icon: Icon(
              followUser
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Details',
            onPressed: onDetails,
            icon: const Icon(Icons.info_outline_rounded),
          ),
          IconButton(
            tooltip: 'Exit navigation',
            onPressed: onExit,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _NavigationMetrics {
  const _NavigationMetrics({
    required this.distanceText,
    required this.etaText,
    required this.nextStep,
  });

  final String distanceText;
  final String etaText;
  final String nextStep;
}

class _RoutePreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = AppColors.primaryText.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final routePaint = Paint()
      ..color = AppColors.secondaryAction
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.70)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.58,
        size.width * 0.42,
        size.height * 0.62,
        size.width * 0.52,
        size.height * 0.49,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.36,
        size.width * 0.76,
        size.height * 0.46,
        size.width * 0.84,
        size.height * 0.32,
      );
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, routePaint);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.70),
      8,
      Paint()..color = AppColors.primaryAction,
    );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.32),
      10,
      Paint()..color = AppColors.secondaryAction,
    );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.32),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.primaryText,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: AppColors.mutedText),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneIconBadge extends StatelessWidget {
  const _ZoneIconBadge({required this.palette, required this.zone});

  final _ZonePalette palette;
  final ZoneModel zone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border.withValues(alpha: 0.55)),
      ),
      child: Icon(_zoneIcon(zone), color: palette.accent, size: 25),
    );
  }
}

IconData _zoneIcon(ZoneModel zone) {
  final identity = _zoneIdentity(zone);
  if (identity == 'Food Hotspot') return Icons.restaurant_rounded;
  if (identity == 'Transport Zone') return Icons.directions_bus_rounded;
  if (identity == 'Student Area') return Icons.school_rounded;
  if (identity == 'Commercial Zone') return Icons.shopping_bag_rounded;
  if (identity == 'Safety Concern') return Icons.warning_amber_rounded;
  if (identity.contains('Hotel')) return Icons.hotel_rounded;
  if (identity == 'Tourist Area') return Icons.photo_camera_rounded;
  if (identity == 'Local Area') return Icons.groups_rounded;
  return Icons.explore_rounded;
}

class _LoadingZoneCard extends StatelessWidget {
  const _LoadingZoneCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ZoneLegendPanel extends StatelessWidget {
  const _ZoneLegendPanel({
    required this.expanded,
    required this.enabledKeys,
    required this.onToggleExpanded,
    required this.onToggleLayer,
  });

  final bool expanded;
  final Set<String> enabledKeys;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onToggleLayer;

  static const _items = <({String key, String label, Color color})>[
    (key: 'local', label: 'Local', color: AppColors.localAccent),
    (
      key: 'international',
      label: 'International',
      color: AppColors.touristAccent,
    ),
    (key: 'mixed', label: 'Mixed', color: AppColors.mixedAccent),
    (key: 'commercial', label: 'Commercial', color: AppColors.commercialAccent),
    (key: 'food', label: 'Food', color: AppColors.foodAccent),
    (key: 'transport', label: 'Transport', color: AppColors.transportAccent),
    (key: 'school', label: 'School', color: AppColors.studentAccent),
    (key: 'tourist', label: 'Tourist', color: AppColors.touristAccent),
    (key: 'safety', label: 'Safety', color: AppColors.safetyAccent),
    (key: 'hotel', label: 'Hotel', color: AppColors.zoneCommercial),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(10),
      constraints: BoxConstraints(maxWidth: expanded ? 250 : 52),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Zone Layers',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onToggleExpanded,
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _items.map((item) {
                    final active = enabledKeys.contains(item.key);
                    return FilterChip(
                      selected: active,
                      onSelected: (_) => onToggleLayer(item.key),
                      label: Text(item.label),
                      side: BorderSide(
                        color: active ? item.color : AppColors.border,
                      ),
                      selectedColor: item.color.withValues(alpha: 0.12),
                      checkmarkColor: item.color,
                      labelStyle: TextStyle(
                        color: active ? item.color : AppColors.secondaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            )
          : InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  Icons.layers_outlined,
                  color: AppColors.primaryText,
                ),
              ),
            ),
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.heroTag,
    required this.icon,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: heroTag,
        elevation: 6,
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        onPressed: onPressed,
        child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
      ),
    );
  }
}

class _BottomQuickActionBar extends StatelessWidget {
  const _BottomQuickActionBar({
    required this.onZoneAlert,
    required this.onCommunity,
    required this.onTrends,
  });

  final VoidCallback onZoneAlert;
  final VoidCallback onCommunity;
  final VoidCallback onTrends;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionBubble(
          icon: Icons.warning_amber_rounded,
          label: 'Zone Alert',
          gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
          onTap: onZoneAlert,
        ),
        _QuickActionBubble(
          icon: Icons.groups_rounded,
          label: 'Community',
          gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          onTap: onCommunity,
        ),
        _QuickActionBubble(
          icon: Icons.show_chart_rounded,
          label: 'Trends',
          gradient: const [Color(0xFF22D3EE), Color(0xFF06B6D4)],
          onTap: onTrends,
        ),
      ],
    );
  }
}

class _QuickActionBubble extends StatelessWidget {
  const _QuickActionBubble({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: gradient),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F172A),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
