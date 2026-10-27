import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/constants/mapbox_config.dart';
import '../../../shared/models/sensitive_site.dart';

class SensitiveSitePreview extends StatefulWidget {
  const SensitiveSitePreview({
    super.key,
    required this.pin,
    required this.sites,
  });

  final LatLng pin;
  final List<SensitiveSite> sites;

  @override
  State<SensitiveSitePreview> createState() => _SensitiveSitePreviewState();
}

class _SensitiveSitePreviewState extends State<SensitiveSitePreview> {
  static const _sourceId = 'sensitive-sites-preview';
  static const _fillId = 'sensitive-sites-preview-fill';
  static const _lineId = 'sensitive-sites-preview-line';
  MapLibreMapController? _controller;
  var _layersReady = false;

  @override
  void didUpdateWidget(covariant SensitiveSitePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pin != widget.pin || oldWidget.sites != widget.sites) {
      unawaitedDraw();
    }
  }

  void unawaitedDraw() {
    final controller = _controller;
    if (controller == null) return;
    Future<void>(() async {
      await _draw(controller);
    });
  }

  Future<void> _draw(MapLibreMapController controller) async {
    final geoJson = sensitiveSitesGeoJson(widget.sites);
    try {
      if (!_layersReady) {
        await controller.addGeoJsonSource(_sourceId, geoJson);
        await controller.addFillLayer(
          _sourceId,
          _fillId,
          const FillLayerProperties(
            fillColor: '#64748B',
            fillOpacity: 0.22,
          ),
        );
        await controller.addLineLayer(
          _sourceId,
          _lineId,
          const LineLayerProperties(
            lineColor: '#64748B',
            lineWidth: 1.4,
            lineOpacity: 0.55,
          ),
        );
        _layersReady = true;
      } else {
        await controller.setGeoJsonSource(_sourceId, geoJson);
      }
      await controller.clearCircles();
      await controller.addCircle(
        CircleOptions(
          geometry: widget.pin,
          circleRadius: 6,
          circleColor: '#0F172A',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 160,
        child: MapLibreMap(
          styleString: MapboxConfig.mapStyleUrl,
          initialCameraPosition: CameraPosition(target: widget.pin, zoom: 16.4),
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          compassEnabled: false,
          myLocationEnabled: false,
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: () {
            final controller = _controller;
            if (controller == null) return;
            _layersReady = false;
            unawaitedDraw();
          },
        ),
      ),
    );
  }
}
