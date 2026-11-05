import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class PlacePick {
  final double latitude;
  final double longitude;
  final int radiusM;
  const PlacePick(this.latitude, this.longitude, this.radiusM);
}

/// Full-screen map: tap to drop a pin, drag the slider to size the area, then confirm.
/// Used for "my home" and for restricted places.
Future<PlacePick?> showPlacePicker(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  LatLng? initial,
  int initialRadius = 150,
  int minRadius = 50,
  int maxRadius = 500,
  Color color = const Color(0xFF667EEA),
  String hint = 'Tap the map to place the pin.',
}) {
  return Navigator.of(context).push<PlacePick>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PlacePickerPage(
        title: title,
        confirmLabel: confirmLabel,
        initial: initial,
        initialRadius: initialRadius,
        minRadius: minRadius,
        maxRadius: maxRadius,
        color: color,
        hint: hint,
      ),
    ),
  );
}

class _PlacePickerPage extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final LatLng? initial;
  final int initialRadius;
  final int minRadius;
  final int maxRadius;
  final Color color;
  final String hint;

  const _PlacePickerPage({
    required this.title,
    required this.confirmLabel,
    required this.initial,
    required this.initialRadius,
    required this.minRadius,
    required this.maxRadius,
    required this.color,
    required this.hint,
  });

  @override
  State<_PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlacePickerPageState extends State<_PlacePickerPage> {
  static const LatLng _fallback = LatLng(-28.7282, 24.7499); // Kimberley
  final MapController _map = MapController();
  LatLng? _pin;
  late double _radius;
  LatLng _center = _fallback;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadius.clamp(widget.minRadius, widget.maxRadius).toDouble();
    if (widget.initial != null) {
      _pin = widget.initial;
      _center = widget.initial!;
    } else {
      _useMyLocation(moveOnly: true);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation({bool moveOnly = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      Position? p;
      try {
        p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
      } catch (_) {
        p = await Geolocator.getLastKnownPosition();
      }
      if (p == null || !mounted) return;
      final here = LatLng(p.latitude, p.longitude);
      setState(() {
        _center = here;
        if (!moveOnly) _pin = here;
      });
      try {
        _map.move(here, 16);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: widget.initial != null ? 16 : 14,
                    onTap: (tapPos, point) => setState(() => _pin = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.safety_accountability',
                      maxNativeZoom: 19,
                    ),
                    if (pin != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: pin,
                            radius: _radius,
                            useRadiusInMeter: true,
                            color: widget.color.withValues(alpha: 0.22),
                            borderColor: widget.color,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    if (pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pin,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: Icon(Icons.location_pin, size: 44, color: widget.color),
                          ),
                        ],
                      ),
                    const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _useMyLocation(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _locating
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location_rounded, color: Color(0xFF007BFF), size: 22),
                      ),
                    ),
                  ),
                ),
                if (pin == null)
                  Positioned(
                    left: 16,
                    right: 70,
                    top: 12,
                    child: Material(
                      color: Colors.white,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(widget.hint, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.radar_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        _radius >= 1000 ? 'Area: ${(_radius / 1000).toStringAsFixed(1)} km' : 'Area: ${_radius.round()} m',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radius,
                    min: widget.minRadius.toDouble(),
                    max: widget.maxRadius.toDouble(),
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: pin == null ? null : () => Navigator.pop(context, PlacePick(pin.latitude, pin.longitude, _radius.round())),
                      child: Text(widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}